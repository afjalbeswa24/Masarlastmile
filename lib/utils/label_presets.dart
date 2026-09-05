class LabelPreset {
  final String name;
  final double pageWidthMm;
  final double pageHeightMm;
  final int columns;
  final int rows;
  // True for pre-cut sticker sheets where the die-cuts butt right up
  // against each other and against the page edge — printing with any page
  // margin or inter-label spacing drifts the grid off the real cut lines
  // as it goes down the page, which is what caused content to overlap
  // onto the next physical sticker.
  final bool zeroGap;
  const LabelPreset(this.name, this.pageWidthMm, this.pageHeightMm, this.columns, this.rows, {this.zeroGap = false});

  int get perPage => columns * rows;
}

const labelPresets = [
  LabelPreset('A4 sheet · 3×4 (12 per page)', 210, 297, 3, 4),
  LabelPreset('A4 sheet · 2×8 (16 per page)', 210, 297, 2, 8),
  LabelPreset('A4 sheet · 2×4 (8 per page)', 210, 297, 2, 4),
  LabelPreset('A4 sheet · 2×2 (4 per page)', 210, 297, 2, 2),
  LabelPreset('A4 sheet · 2×7 (14 per page)', 210, 297, 2, 7),
  // Matches a die-cut sheet of 37×105mm stickers, 2 columns x 8 rows,
  // 0 gap: 2x105=210mm fills the A4 width exactly, 8x37=296mm ≈ the
  // 297mm A4 height (within a fraction of a mm), so with zero margin and
  // zero spacing each printed cell lands exactly on its physical sticker.
  LabelPreset('Pre-cut sticker sheet · 37×105mm, 2×8 (0 margin)', 210, 297, 2, 8, zeroGap: true),
  LabelPreset('Shipping label 4×6 in (1 per page)', 101.6, 152.4, 1, 1),
  LabelPreset('Sticker 3×2 in (1 per page)', 76.2, 50.8, 1, 1),
  LabelPreset('Sticker 60×80mm (1 per page)', 60, 80, 1, 1),
];