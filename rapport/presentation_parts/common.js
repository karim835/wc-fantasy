const {
  Paragraph, TextRun, Table, TableRow, TableCell, AlignmentType, LevelFormat,
  HeadingLevel, BorderStyle, WidthType, ShadingType, Header, Footer, PageNumber,
} = require("docx");

const PAGE = {
  size: { width: 11906, height: 16838 }, // A4
  margin: { top: 1134, right: 1134, bottom: 1134, left: 1134 }, // ~0.8"
};
const CONTENT_WIDTH = 11906 - 1134 - 1134; // 9638

const COLORS = {
  navy: "1F3864",
  gold: "C8961C",
  red: "C41E3A",
  grayLight: "F2F2F2",
  grayBorder: "CCCCCC",
};

function styles() {
  return {
    default: { document: { run: { font: "Calibri", size: 22 } } }, // 11pt
    paragraphStyles: [
      {
        id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, font: "Calibri", color: COLORS.navy },
        paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0,
          border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: COLORS.gold, space: 4 } } },
      },
      {
        id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, font: "Calibri", color: COLORS.red },
        paragraph: { spacing: { before: 260, after: 140 }, outlineLevel: 1 },
      },
      {
        id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 23, bold: true, font: "Calibri", color: "333333" },
        paragraph: { spacing: { before: 180, after: 100 }, outlineLevel: 2 },
      },
    ],
  };
}

function numbering() {
  return {
    config: [
      {
        reference: "bullets",
        levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 560, hanging: 280 } } } }],
      },
      {
        reference: "numbers",
        levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 560, hanging: 280 } } } }],
      },
    ],
  };
}

function titlePage(title, subtitle, role) {
  return [
    new Paragraph({ spacing: { before: 1200 }, alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: "PFA — Projet de Fin d'Année 2025-2026", size: 24, color: "666666" })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 200, after: 100 },
      children: [new TextRun({ text: "WC Fantasy", size: 56, bold: true, color: COLORS.navy })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
      children: [new TextRun({ text: "Application Fantasy Football — Coupe du Monde FIFA 2026", size: 26, color: COLORS.red, italics: true })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 800, after: 100 },
      children: [new TextRun({ text: title, size: 36, bold: true, color: COLORS.gold })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 },
      children: [new TextRun({ text: subtitle, size: 24, color: "444444" })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1000 },
      children: [new TextRun({ text: `Document de préparation — ${role}`, size: 20, italics: true, color: "888888" })] }),
    new Paragraph({ children: [], pageBreakBefore: false }),
  ];
}

function h1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(text)] });
}
function h2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(text)] });
}
function h3(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(text)] });
}
function p(text, opts = {}) {
  return new Paragraph({ spacing: { after: 140 }, children: [new TextRun({ text, ...opts })] });
}
function pBold(label, rest) {
  return new Paragraph({ spacing: { after: 140 }, children: [
    new TextRun({ text: label, bold: true }),
    new TextRun({ text: rest }),
  ] });
}
function bullet(text, opts = {}) {
  return new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 },
    children: [new TextRun({ text, ...opts })] });
}
function bulletRich(runs) {
  return new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: runs });
}
function num(text) {
  return new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 80 },
    children: [new TextRun(text)] });
}
function code(lines) {
  return new Paragraph({
    spacing: { after: 200, before: 80 },
    shading: { fill: "1E1E1E", type: ShadingType.CLEAR },
    border: { top: { style: BorderStyle.SINGLE, size: 2, color: "333333" }, bottom: { style: BorderStyle.SINGLE, size: 2, color: "333333" },
      left: { style: BorderStyle.SINGLE, size: 2, color: "333333" }, right: { style: BorderStyle.SINGLE, size: 2, color: "333333" } },
    children: lines.flatMap((l, i) => i === 0 ? [new TextRun({ text: l, font: "Consolas", size: 18, color: "D4D4D4" })]
      : [new TextRun({ text: "", break: 1 }), new TextRun({ text: l, font: "Consolas", size: 18, color: "D4D4D4" })]),
  });
}
function quote(text) {
  return new Paragraph({
    spacing: { after: 200, before: 80 }, indent: { left: 280 },
    border: { left: { style: BorderStyle.SINGLE, size: 16, color: COLORS.gold, space: 8 } },
    children: [new TextRun({ text, italics: true, color: "555555" })],
  });
}

function table2col(header, rows, widths = [3000, 6638]) {
  const border = { style: BorderStyle.SINGLE, size: 1, color: COLORS.grayBorder };
  const borders = { top: border, bottom: border, left: border, right: border };
  const mkCell = (text, w, isHeader) => new TableCell({
    borders, width: { size: w, type: WidthType.DXA },
    shading: isHeader ? { fill: COLORS.navy, type: ShadingType.CLEAR } : { fill: "FFFFFF", type: ShadingType.CLEAR },
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    children: [new Paragraph({ children: [new TextRun({ text, bold: !!isHeader, color: isHeader ? "FFFFFF" : "000000", size: 20 })] })],
  });
  return new Table({
    width: { size: widths[0] + widths[1], type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: [mkCell(header[0], widths[0], true), mkCell(header[1], widths[1], true)] }),
      ...rows.map((r, idx) => new TableRow({ children: [
        new TableCell({ borders, width: { size: widths[0], type: WidthType.DXA }, shading: { fill: idx % 2 ? COLORS.grayLight : "FFFFFF", type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 }, children: [new Paragraph({ children: [new TextRun({ text: r[0], size: 20, bold: true })] })] }),
        new TableCell({ borders, width: { size: widths[1], type: WidthType.DXA }, shading: { fill: idx % 2 ? COLORS.grayLight : "FFFFFF", type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 }, children: [new Paragraph({ children: [new TextRun({ text: r[1], size: 20 })] })] }),
      ] })),
    ],
  });
}

function tableN(headers, rows, widths) {
  const border = { style: BorderStyle.SINGLE, size: 1, color: COLORS.grayBorder };
  const borders = { top: border, bottom: border, left: border, right: border };
  const mkCell = (text, w, isHeader, shade) => new TableCell({
    borders, width: { size: w, type: WidthType.DXA },
    shading: { fill: isHeader ? COLORS.navy : shade, type: ShadingType.CLEAR },
    margins: { top: 70, bottom: 70, left: 100, right: 100 },
    children: [new Paragraph({ children: [new TextRun({ text: String(text), bold: !!isHeader, color: isHeader ? "FFFFFF" : "000000", size: 19 })] })],
  });
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: headers.map((hd, i) => mkCell(hd, widths[i], true)) }),
      ...rows.map((r, idx) => new TableRow({ children: r.map((c, i) => mkCell(c, widths[i], false, idx % 2 ? COLORS.grayLight : "FFFFFF")) })),
    ],
  });
}

function footer() {
  return new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
    children: [
      new TextRun({ text: "WC Fantasy — PFA 2025-2026   |   Page ", size: 16, color: "999999" }),
      new TextRun({ children: [PageNumber.CURRENT], size: 16, color: "999999" }),
    ] })] });
}
function header(title) {
  return new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT,
    children: [new TextRun({ text: title, size: 16, color: "999999", italics: true })] })] });
}

module.exports = { PAGE, CONTENT_WIDTH, COLORS, styles, numbering, titlePage, h1, h2, h3, p, pBold, bullet, bulletRich, num, code, quote, table2col, tableN, footer, header };
