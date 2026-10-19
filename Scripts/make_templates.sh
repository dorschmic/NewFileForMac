#!/bin/bash
# Erzeugt die mitgelieferten Vorlagen in Resources/Templates.
#
# Office-Dateien (.docx/.xlsx/.pptx) sind ZIP-Archive mit XML-Dateien –
# eine 0-Byte-Datei mit dieser Endung lässt sich NICHT öffnen. Hier werden
# daher minimale, gültige Pakete gebaut.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$PWD/Resources/Templates"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# --- Textbasierte Vorlagen ------------------------------------------------
: > "$OUT/10 Textdokument.txt"
: > "$OUT/20 Markdown.md"
printf '#!/usr/bin/env python3\n\n' > "$OUT/30 Python-Skript.py"
cat > "$OUT/40 HTML-Seite.html" <<'EOF'
<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title></title>
</head>
<body>

</body>
</html>
EOF
printf '{}\n' > "$OUT/50 JSON.json"
: > "$OUT/60 CSV-Tabelle.csv"
printf '#!/bin/zsh\n\n' > "$OUT/70 Shell-Skript.sh"
chmod +x "$OUT/70 Shell-Skript.sh"
printf '{\\rtf1\\ansi\\ansicpg1252\\deff0\n}\n' > "$OUT/80 RTF-Dokument.rtf"

# --- Office ---------------------------------------------------------------
REL='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
PKG='http://schemas.openxmlformats.org/package/2006/relationships'
CT='http://schemas.openxmlformats.org/package/2006/content-types'
HDR='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'

pack() { # pack <Quellordner> <Zieldatei>
  (cd "$1" && rm -f "$2" && zip -X -D -q -r "$2" '[Content_Types].xml' . -x '[Content_Types].xml')
}

# Word (A4)
D="$WORK/docx"; mkdir -p "$D/_rels" "$D/word"
cat > "$D/[Content_Types].xml" <<EOF
$HDR
<Types xmlns="$CT"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
EOF
cat > "$D/_rels/.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/officeDocument" Target="word/document.xml"/></Relationships>
EOF
cat > "$D/word/document.xml" <<EOF
$HDR
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1417" w:right="1417" w:bottom="1134" w:left="1417" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>
EOF
pack "$D" "$OUT/90 Word-Dokument.docx"

# Excel
X="$WORK/xlsx"; mkdir -p "$X/_rels" "$X/xl/_rels" "$X/xl/worksheets"
cat > "$X/[Content_Types].xml" <<EOF
$HDR
<Types xmlns="$CT"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
EOF
cat > "$X/_rels/.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/officeDocument" Target="xl/workbook.xml"/></Relationships>
EOF
cat > "$X/xl/workbook.xml" <<EOF
$HDR
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="$REL"><sheets><sheet name="Tabelle1" sheetId="1" r:id="rId1"/></sheets></workbook>
EOF
cat > "$X/xl/_rels/workbook.xml.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="$REL/styles" Target="styles.xml"/></Relationships>
EOF
cat > "$X/xl/worksheets/sheet1.xml" <<EOF
$HDR
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>
EOF
cat > "$X/xl/styles.xml" <<EOF
$HDR
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
EOF
pack "$X" "$OUT/91 Excel-Tabelle.xlsx"

# PowerPoint (16:9, ohne Folien – PowerPoint braucht Master, Layout und Theme)
P="$WORK/pptx"; mkdir -p "$P/_rels" "$P/ppt/_rels" "$P/ppt/slideMasters/_rels" "$P/ppt/slideLayouts/_rels" "$P/ppt/theme"
NS='xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="'$REL'" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
TREE='<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>'
cat > "$P/[Content_Types].xml" <<EOF
$HDR
<Types xmlns="$CT"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/></Types>
EOF
cat > "$P/_rels/.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/officeDocument" Target="ppt/presentation.xml"/></Relationships>
EOF
cat > "$P/ppt/presentation.xml" <<EOF
$HDR
<p:presentation $NS saveSubsetFonts="1"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>
EOF
cat > "$P/ppt/_rels/presentation.xml.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rId2" Type="$REL/theme" Target="theme/theme1.xml"/></Relationships>
EOF
cat > "$P/ppt/slideMasters/slideMaster1.xml" <<EOF
$HDR
<p:sldMaster $NS><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>$TREE</p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle><a:lvl1pPr><a:defRPr sz="4400"/></a:lvl1pPr></p:titleStyle><p:bodyStyle><a:lvl1pPr><a:defRPr sz="2800"/></a:lvl1pPr></p:bodyStyle><p:otherStyle><a:lvl1pPr><a:defRPr sz="1800"/></a:lvl1pPr></p:otherStyle></p:txStyles></p:sldMaster>
EOF
cat > "$P/ppt/slideMasters/_rels/slideMaster1.xml.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="$REL/theme" Target="../theme/theme1.xml"/></Relationships>
EOF
cat > "$P/ppt/slideLayouts/slideLayout1.xml" <<EOF
$HDR
<p:sldLayout $NS type="blank" preserve="1"><p:cSld name="Leer">$TREE</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
EOF
cat > "$P/ppt/slideLayouts/_rels/slideLayout1.xml.rels" <<EOF
$HDR
<Relationships xmlns="$PKG"><Relationship Id="rId1" Type="$REL/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>
EOF
FILL='<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
cat > "$P/ppt/theme/theme1.xml" <<EOF
$HDR
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office"><a:themeElements><a:clrScheme name="Office"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4><a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="Office"><a:fillStyleLst>$FILL$FILL$FILL</a:fillStyleLst><a:lnStyleLst><a:ln w="6350">$FILL</a:ln><a:ln w="12700">$FILL</a:ln><a:ln w="19050">$FILL</a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst>$FILL$FILL$FILL</a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>
EOF
pack "$P" "$OUT/92 PowerPoint-Präsentation.pptx"

echo "Vorlagen erzeugt in $OUT:"
ls -l "$OUT"
