import SwiftUI

struct IntroView: View {
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHola = false
    @State private var revealedLetters = 0
    @State private var showUnderline = false
    @State private var isLeaving = false

    private let name = Array("Hablemos")

    var body: some View {
        ZStack {
            Noche.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Orb(size: 112, mood: showHola ? .speaking : .idle)
                    .opacity(showHola ? 1 : 0)
                    .scaleEffect(showHola ? 1 : 0.4)
                    .padding(.bottom, 12)
                Text("¡Hola!")
                    .font(.display(56, relativeTo: .largeTitle))
                    .foregroundStyle(Noche.brandText)
                    .opacity(showHola ? 1 : 0)
                    .scaleEffect(showHola ? 1 : 0.7)
                    .offset(y: showHola ? 0 : 16)

                HStack(spacing: 0) {
                    ForEach(Array(name.enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            .font(.display(40, relativeTo: .title))
                            .tracking(-0.5)
                            .foregroundStyle(Noche.text)
                            .opacity(index < revealedLetters ? 1 : 0)
                            .offset(y: index < revealedLetters ? 0 : 12)
                    }
                }

                Capsule()
                    .fill(Noche.mint)
                    .frame(width: showUnderline ? 120 : 0, height: 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("¡Hola! Hablemos")
        }
        .opacity(isLeaving ? 0 : 1)
        .scaleEffect(isLeaving ? 1.06 : 1)
        .task { await play() }
    }

    private func play() async {
        guard !reduceMotion else {
            showHola = true
            revealedLetters = name.count
            showUnderline = true
            try? await Task.sleep(for: .seconds(1))
            onFinish()
            return
        }
        withAnimation(.spring(duration: 0.6, bounce: 0.3)) { showHola = true }
        try? await Task.sleep(for: .milliseconds(650))
        for count in 1...name.count {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { revealedLetters = count }
            try? await Task.sleep(for: .milliseconds(70))
        }
        withAnimation(.easeOut(duration: 0.5)) { showUnderline = true }
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeIn(duration: 0.45)) { isLeaving = true }
        try? await Task.sleep(for: .milliseconds(450))
        onFinish()
    }
}

#Preview { IntroView(onFinish: {}) }
