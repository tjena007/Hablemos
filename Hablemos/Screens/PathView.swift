import HablemosCore
import SwiftUI

/// The course roadmap: what's done, what's up next, and what comes after.
struct PathView: View {
    let completed: Set<String>
    let level: CEFRLevel
    let onStart: () -> Void
    @State private var expanded: Set<String> = []

    private var next: Lesson? { Course.nextLesson(completed: completed, level: level) }

    private enum Status { case done, now, later }

    private func status(of unit: CourseUnit) -> Status {
        if unit.lessons.allSatisfy({ completed.contains($0.id) }) { return .done }
        if let next, unit.lessons.contains(where: { $0.id == next.id }) { return .now }
        return .later
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    UpperLabel(text: "Level \(level.rawValue)", color: Noche.brandText)
                    Text("Your path")
                        .font(.display(30, relativeTo: .largeTitle))
                        .tracking(-0.5)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.bottom, 8)
                .entrance(0)
                if next == nil {
                    Text(level == .a1 ? "You've finished every lesson. Lucía will keep practising with you in free conversation." : "Guided lessons cover A1 so far. Lucía practises your level with you in free conversation.")
                        .font(.subheadline)
                        .foregroundStyle(Noche.textSoft)
                        .entrance(1)
                }
                ForEach(Array(Course.units.enumerated()), id: \.element.id) { index, unit in
                    unitCard(unit).entrance(index + 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .animation(.hablemos, value: expanded)
        }
        .onAppear {
            if let next, let unit = Course.unit(containing: next.id) { expanded.insert(unit.id) }
        }
    }

    private func unitCard(_ unit: CourseUnit) -> some View {
        let status = status(of: unit)
        let isOpen = expanded.contains(unit.id)
        let doneCount = unit.lessons.filter { completed.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 14) {
            Button {
                if isOpen { expanded.remove(unit.id) } else { expanded.insert(unit.id) }
            } label: {
                HStack(spacing: 14) {
                    unitBadge(status)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status == .now ? "Unit \(unit.number) · Now" : "Unit \(unit.number)")
                            .font(.caption.weight(status == .now ? .semibold : .regular))
                            .foregroundStyle(status == .now ? Noche.brandText : Noche.textMuted)
                        Text(unit.title)
                            .font(status == .now ? .display(22) : .callout.weight(.semibold))
                            .foregroundStyle(status == .later ? Noche.textSoft : Noche.text)
                        if status == .now || isOpen {
                            Text(unit.subtitle).font(.footnote).foregroundStyle(Noche.textMuted)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(status == .done ? "Done" : "\(doneCount) / \(unit.lessons.count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(status == .done ? Noche.mint : Noche.textSoft)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Noche.textMuted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint(isOpen ? "Hides the lessons" : "Shows the lessons")
            if isOpen {
                VStack(spacing: 0) {
                    ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                        lessonRow(lesson, number: index + 1)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card(
            fill: status == .later ? Noche.bg : status == .now ? Noche.surfaceHi : Noche.surface,
            border: status == .now ? Noche.brandBorder : status == .later ? Noche.border : .clear,
            borderWidth: status == .done ? 0 : 1,
            radius: 22,
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        )
    }

    @ViewBuilder
    private func unitBadge(_ status: Status) -> some View {
        switch status {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Noche.mint)
                .frame(width: 40, height: 40)
                .background(Noche.surfaceMint, in: Circle())
        case .now:
            Orb(size: 40)
        case .later:
            Image(systemName: "lock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Noche.textMuted)
                .frame(width: 40, height: 40)
                .background(Noche.surfaceHi, in: Circle())
        }
    }

    @ViewBuilder
    private func lessonRow(_ lesson: Lesson, number: Int) -> some View {
        let isDone = completed.contains(lesson.id)
        let isNext = lesson.id == next?.id
        let row = HStack(spacing: 12) {
            Group {
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Noche.mint)
                } else if isNext {
                    Orb(size: 20)
                } else {
                    Circle().strokeBorder(Noche.borderDashed, lineWidth: 2).frame(width: 12, height: 12)
                }
            }
            .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number) · \(lesson.scenario.title)")
                    .font(.subheadline.weight(isNext ? .semibold : .regular))
                    .foregroundStyle(isNext ? Noche.text : isDone ? Noche.textSoft : Noche.textMuted)
                if isNext {
                    Text(lesson.scenario.subtitle).font(.caption).foregroundStyle(Noche.textMuted)
                }
            }
            Spacer(minLength: 8)
            if isNext {
                Text("Start").font(.footnote.weight(.semibold)).foregroundStyle(Noche.brandText)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: isNext ? 56 : 44)
        .background(isNext ? Noche.brandSurface : .clear, in: RoundedRectangle(cornerRadius: 14))

        if isNext {
            Button(action: onStart) { row }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Start lesson \(number), \(lesson.scenario.title)")
        } else {
            row
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? "Done" : "Not started")
        }
    }
}
