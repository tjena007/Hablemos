import AVFoundation
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [LearnerProfile]
    @State private var errorMessage: String?

    private static let locales = ["es-MX", "es-ES"]
    private static let defaultRate = Double(AVSpeechUtteranceDefaultSpeechRate)

    private let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("es") }
        .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.display(28, relativeTo: .largeTitle))
                    .foregroundStyle(Noche.text)
                    .accessibilityAddTraits(.isHeader)
                if let profile = profiles.first {
                    content(Bindable(profile))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Noche.bg.ignoresSafeArea())
        .task {
            guard profiles.isEmpty else { return }
            do { _ = try ProgressStore(context: context).profile() } catch { errorMessage = error.localizedDescription }
        }
        .alert(
            "Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(_ profile: Bindable<LearnerProfile>) -> some View {
        localeSection(profile)
        rateSection(profile)
        modelSection(profile)
        voiceSection(profile)
    }

    private func localeSection(_ profile: Bindable<LearnerProfile>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "Spanish variant")
            Picker("Spanish variant", selection: profile.localeIdentifier) {
                Text("Mexico (es-MX)").tag("es-MX")
                Text("Spain (es-ES)").tag("es-ES")
            }
            .pickerStyle(.segmented)
        }
        .card()
    }

    private func rateSection(_ profile: Bindable<LearnerProfile>) -> some View {
        let automatic = Binding(
            get: { profile.wrappedValue.ttsRateOverride == nil },
            set: { profile.wrappedValue.ttsRateOverride = $0 ? nil : Float(Self.defaultRate) }
        )
        let rate = Binding(
            get: { Double(profile.wrappedValue.ttsRateOverride ?? Float(Self.defaultRate)) },
            set: { profile.wrappedValue.ttsRateOverride = Float($0) }
        )
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "Speaking speed")
            Toggle("Automatic", isOn: automatic)
                .foregroundStyle(Noche.textSoft)
                .tint(Noche.saffron)
            Slider(
                value: rate,
                in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)
            )
            .tint(Noche.saffron)
            .disabled(automatic.wrappedValue)
            .accessibilityLabel("Speaking speed")
        }
        .card()
    }

    private func modelSection(_ profile: Bindable<LearnerProfile>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "Model")
            Picker("Model", selection: profile.useE2BModel) {
                Text("E4B").tag(false)
                Text("E2B").tag(true)
            }
            .pickerStyle(.segmented)
            Text("E4B is more accurate. E2B is smaller and faster.")
                .font(.caption)
                .foregroundStyle(Noche.textMuted)
        }
        .card()
    }

    private func voiceSection(_ profile: Bindable<LearnerProfile>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeading(text: "Voice")
            if voices.isEmpty {
                Text("No Spanish voices are installed.")
                    .font(.subheadline)
                    .foregroundStyle(Noche.textMuted)
            }
            ForEach(voices, id: \.identifier) { voice in
                let selected = profile.wrappedValue.voiceIdentifier == voice.identifier
                Button {
                    profile.wrappedValue.voiceIdentifier = voice.identifier
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.name).foregroundStyle(Noche.text)
                            Text("\(voice.language) · \(Self.label(for: voice.quality))")
                                .font(.caption)
                                .foregroundStyle(Noche.textMuted)
                        }
                        Spacer()
                        if selected { Image(systemName: "checkmark").foregroundStyle(Noche.saffron) }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Text("Download more voices in iOS Settings > Accessibility > Spoken Content.")
                .font(.caption)
                .foregroundStyle(Noche.textMuted)
                .padding(.top, 6)
        }
        .card()
    }

    private static func label(for quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
    }
}

#Preview {
    let container = try! PersistenceSchema.makeContainer(inMemory: true)
    container.mainContext.insert(LearnerProfile(level: .a2))
    return SettingsView().modelContainer(container)
}
