import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Some spreadsheet tools write built-in number formats (IDs 0–163 are
/// reserved by the OOXML spec for Excel's own formats — e.g. 42 and 44 are
/// the standard accounting formats) into the file's *custom* number format
/// list, which is only supposed to hold IDs 164 and above. That's technically
/// redundant rather than genuinely broken — Excel itself ignores the
/// duplication and just uses its own built-in definition — but the `excel`
/// package's parser is stricter and throws "custom numFmtId starts at 164
/// but found a value of X" on files like this.
///
/// This opens the xlsx (which is just a zip file), strips any such entries
/// out of xl/styles.xml, and returns the repaired bytes — leaving every
/// other part of the file, and all the actual data, untouched. If anything
/// about the file doesn't match what's expected (not a zip, no styles.xml,
/// etc.), this returns the original bytes unchanged rather than risk
/// corrupting a file that didn't need repairing in the first place.
Uint8List repairXlsxNumFmts(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? stylesFile;
    for (final f in archive.files) {
      if (f.name == 'xl/styles.xml') {
        stylesFile = f;
        break;
      }
    }
    if (stylesFile == null) return bytes;

    final original = utf8.decode(stylesFile.content as List<int>, allowMalformed: true);

    final countMatch = RegExp(r'<numFmts count="(\d+)">').firstMatch(original);
    if (countMatch == null) return bytes; // no custom number formats at all — nothing to repair

    // Only IDs 164+ are valid in this section; anything lower is a built-in
    // format that shouldn't be listed here.
    var fixed = original.replaceAllMapped(
      RegExp(r'<numFmt numFmtId="(\d+)"[^/]*/>'),
      (m) {
        final id = int.tryParse(m.group(1) ?? '') ?? 999;
        return id < 164 ? '' : m[0]!;
      },
    );

    final remaining = RegExp(r'<numFmt numFmtId=').allMatches(fixed).length;
    if (remaining == int.parse(countMatch.group(1)!)) return bytes; // nothing was actually removed

    fixed = remaining == 0
        ? fixed.replaceFirst(RegExp(r'<numFmts count="\d+">\s*</numFmts>'), '')
        : fixed.replaceFirst(RegExp(r'<numFmts count="\d+">'), '<numFmts count="$remaining">');

    final newArchive = Archive();
    for (final file in archive.files) {
      if (file.name == 'xl/styles.xml') {
        final data = Uint8List.fromList(utf8.encode(fixed));
        newArchive.addFile(ArchiveFile('xl/styles.xml', data.length, data));
      } else if (file.isFile) {
        newArchive.addFile(ArchiveFile(file.name, file.size, file.content));
      }
    }

    final encoded = ZipEncoder().encode(newArchive);
    return encoded != null ? Uint8List.fromList(encoded) : bytes;
  } catch (_) {
    // If anything goes wrong repairing it, fall back to the original bytes
    // — a normal file that never needed this will parse exactly as before.
    return bytes;
  }
}