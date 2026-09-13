import Foundation
import PDFKit
import AppKit

// Run from the repository root. Render the diagram rectangle directly from
// PDF page 19; no OCR text or reconstructed edges are painted onto the scan.
let root = URL(fileURLWithPath: "mlir/insider-compiler")
let pdf = PDFDocument(url: root.appendingPathComponent("pdf/insider-compiler-ch7-ch10.pdf"))!
let page = pdf.page(at: 18)!
let scale: CGFloat = 4
// PDF coordinates have their origin at the lower left.
let rect = CGRect(x: 88, y: 463, width: 462, height: 291)
let width = Int(rect.width * scale), height = Int(rect.height * scale)
let context = CGContext(data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.scaleBy(x: scale, y: scale)
context.translateBy(x: -rect.minX, y: -rect.minY)
page.draw(with: .mediaBox, to: context)
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(
    to: root.appendingPathComponent("issues/evidence/part2/diagram-original.png"))
