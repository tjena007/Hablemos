import SwiftUI
import UniformTypeIdentifiers

struct ModelSetupView: View {
    let onReady: () -> Void

    @State private var variant: ModelVariant = .e4b
    @State private var downloaders: [ModelVariant: ModelDownloader] = Dictionary(
        uniqueKeysWithValues: ModelVariant.allCases.map { ($0, ModelDownloader(variant: $0)) }
    )
    @State private var importer = ModelImporter()
    @State private var isPickingFile = false
    @State private var pickerError: String?

    private var downloader: ModelDownloader { downloaders[variant]! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set up your tutor")
                        .font(.display(28, relativeTo: .title))
                        .foregroundStyle(Noche.text)
                    Text("Hablemos runs its language model on your device, so conversations stay private and work offline.")
                        .font(.callout)
                        .foregroundStyle(Noche.textMuted)
                }

                SectionHeading(text: "Choose a model")
                ForEach(ModelVariant.allCases) { option in
                    variantCard(option)
                }

                Text("The model is about 3.7 GB. Wi-Fi is advised, and you can pause the download any time.")
                    .font(.footnote)
                    .foregroundStyle(Noche.textMuted)

                actions
                status
            }
            .padding(20)
        }
        .background(Noche.bg.ignoresSafeArea())
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.data]) { result in
            switch result {
            case let .success(url): importer.start(from: url, variant: variant)
            case let .failure(error): pickerError = error.localizedDescription
            }
        }
        .task(id: variant) {
            await downloader.restore()
            if ModelStore.isInstalled(variant) { onReady() }
        }
        .onChange(of: downloader.state) { _, new in
            if new == .done { onReady() }
        }
        .onChange(of: importer.state) { _, new in
            if new == .done { onReady() }
        }
    }

    private func variantCard(_ option: ModelVariant) -> some View {
        let isSelected = option == variant
        return Button {
            variant = option
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option == .e4b ? "Gemma E4B" : "Gemma E2B")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Noche.text)
                    Text(option == .e4b ? "Best quality, ~3.7 GB" : "Smaller and faster, ~2.6 GB")
                        .font(.subheadline)
                        .foregroundStyle(Noche.textMuted)
                }
                Spacer()
                if option == .e4b { Chip(text: "Recommended") }
            }
            .card(
                fill: isSelected ? Noche.surfaceSel : Noche.surface,
                border: isSelected ? Noche.saffron : Noche.border
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var actions: some View {
        switch downloader.state {
        case .idle, .failed:
            PrimaryButton(title: "Download model") { downloader.start() }
        case .paused:
            PrimaryButton(title: "Resume download") { downloader.start() }
            SecondaryButton(title: "Cancel download") { downloader.cancel() }
        case .downloading:
            SecondaryButton(title: "Pause") { downloader.pause() }
            SecondaryButton(title: "Cancel download") { downloader.cancel() }
        case .done:
            PrimaryButton(title: "Continue") { onReady() }
        }
        if case .importing = importer.state {
            SecondaryButton(title: "Cancel import") { importer.cancel() }
        } else if downloader.state != .done {
            SecondaryButton(title: "Import from Files") { isPickingFile = true }
        }
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case let .downloading(fraction) = downloader.state {
                ThinProgressBar(fraction: fraction)
                Text("\(bytes(downloader.bytesWritten)) of \(bytes(downloader.totalBytes))")
                    .font(.footnote).foregroundStyle(Noche.textMuted)
            }
            if downloader.state == .paused {
                ThinProgressBar(fraction: downloader.fraction)
                Text("Paused at \(Int(downloader.fraction * 100))%")
                    .font(.footnote).foregroundStyle(Noche.textMuted)
            }
            if case let .importing(fraction) = importer.state {
                ThinProgressBar(fraction: fraction)
                Text("Importing \(Int(fraction * 100))%")
                    .font(.footnote).foregroundStyle(Noche.textMuted)
            }
            if case let .failed(message) = downloader.state { errorText(message) }
            if case let .failed(message) = importer.state { errorText(message) }
            if let pickerError { errorText(pickerError) }
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Noche.coralText)
            .card(fill: Noche.coralSurface, border: Noche.coralBorder)
    }

    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
