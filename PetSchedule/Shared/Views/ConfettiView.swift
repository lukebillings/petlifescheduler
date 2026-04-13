import SwiftUI

struct ConfettiView: UIViewRepresentable {
    let trigger: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ConfettiUIView {
        let view = ConfettiUIView()
        return view
    }

    func updateUIView(_ uiView: ConfettiUIView, context: Context) {
        guard trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        guard trigger > 0 else { return }
        // Defer so the view has its final bounds from SwiftUI layout
        DispatchQueue.main.async { uiView.burst() }
    }

    class Coordinator {
        var lastTrigger = 0
    }
}

final class ConfettiUIView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func burst() {
        // Clear any in-flight emitters
        layer.sublayers?.filter { $0 is CAEmitterLayer }.forEach { $0.removeFromSuperlayer() }

        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: width / 2, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: width, height: 1)
        emitter.birthRate = 1

        let colors: [UIColor] = [
            UIColor(red: 248/255, green: 78/255, blue: 166/255, alpha: 1), // appPink
            .systemBlue, .systemYellow, .systemGreen, .systemOrange, .systemPurple, .systemCyan, .systemRed
        ]

        emitter.emitterCells = colors.flatMap { color in
            [makeCell(color: color, isRound: false),
             makeCell(color: color, isRound: true)]
        }

        layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { emitter.removeFromSuperlayer() }
    }

    private func makeCell(color: UIColor, isRound: Bool) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 2
        cell.lifetime = 5
        cell.lifetimeRange = 1
        cell.velocity = 300
        cell.velocityRange = 120
        cell.emissionLongitude = .pi        // fall downward
        cell.emissionRange = .pi / 5
        cell.spin = 3
        cell.spinRange = 4
        cell.scale = 0.45
        cell.scaleRange = 0.2
        cell.contents = makeImage(color: color, isRound: isRound)
        return cell
    }

    private func makeImage(color: UIColor, isRound: Bool) -> CGImage? {
        let size = isRound ? CGSize(width: 8, height: 8) : CGSize(width: 10, height: 6)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            if isRound {
                ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            } else {
                ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            }
        }.cgImage
    }
}
