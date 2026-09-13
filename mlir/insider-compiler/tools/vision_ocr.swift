import Foundation
import PDFKit
import Vision
import AppKit

// Usage: vision-ocr input.pdf output-directory [first-page] [last-page]
// Raw Vision output is preserved without spelling or semantic corrections.
let args = CommandLine.arguments
guard args.count >= 3, let document = PDFDocument(url: URL(fileURLWithPath: args[1])) else {
    fatalError("Usage: vision-ocr input.pdf output-directory [first-page] [last-page]")
}
let output = URL(fileURLWithPath: args[2], isDirectory: true)
let first = args.count > 3 ? Int(args[3])! : 1
let last = args.count > 4 ? Int(args[4])! : document.pageCount
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for pageNumber in first...min(last, document.pageCount) {
    try autoreleasepool {
        let prefix = output.appendingPathComponent(String(format: "page-%03d", pageNumber))
        let alreadyRecognized = FileManager.default.fileExists(atPath: prefix.path + ".json")
        if alreadyRecognized && FileManager.default.fileExists(atPath: prefix.path + ".png") { return }
        let page = document.page(at: pageNumber - 1)!
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 3.0
        let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: ctx)
        let cgImage = ctx.makeImage()!
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: prefix.path + ".png"))
        // Rebuild a missing preview without changing an archived OCR result.
        if alreadyRecognized {
            print("Restored preview for page \(pageNumber)")
            return
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        let lines: [[String: Any]] = observations.enumerated().map { index, observation in
            let candidate = observation.topCandidates(1).first!
            let b = observation.boundingBox
            return ["index": index, "text": candidate.string, "confidence": candidate.confidence,
                    "bbox": [b.minX, b.minY, b.width, b.height]]
        }
        let payload: [String: Any] = ["source": URL(fileURLWithPath: args[1]).lastPathComponent,
            "pdf_page": pageNumber, "total_pages": document.pageCount,
            "engine": "Apple Vision VNRecognizeTextRequest", "revision": request.revision,
            "languages": request.recognitionLanguages, "language_correction": false,
            "render_scale": scale, "width": width, "height": height, "lines": lines]
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") + "\n"
        try text.write(toFile: prefix.path + ".txt", atomically: true, encoding: .utf8)
        try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            .write(to: URL(fileURLWithPath: prefix.path + ".json"), options: .atomic)
        print("\(URL(fileURLWithPath: args[1]).lastPathComponent) page \(pageNumber)/\(document.pageCount): \(observations.count) lines")
        fflush(stdout)
    }
}
