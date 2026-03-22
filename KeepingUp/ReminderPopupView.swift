//
//  ReminderPopupView.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import AppKit
import SwiftUI

struct ReminderPopupView: View {
    let tasks: [StartupTask]
    let primaryMessage: String
    let secondaryMessage: String?
    let textSize: NotificationTextSize
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onExpansionChanged: (Bool) -> Void
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text("KeepingUp")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .background(.white.opacity(0.001))
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }

                Text(primaryMessage)
                    .font(primaryFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let secondaryMessage, !secondaryMessage.isEmpty {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Text(secondaryMessage)
                                .font(secondaryFont)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                                .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(tasks.prefix(5))) { task in
                        Text(task.title)
                            .font(expandedListFont)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if tasks.count > 5 {
                        Text("+ \(tasks.count - 5) more in menu bar")
                            .font(secondaryFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, isExpanded ? 4 : 0)
                .frame(maxHeight: isExpanded ? 140 : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: popupWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onDismiss()
        }
        .onHover { isHovering in
            onHoverChanged(isHovering)
        }
        .onChange(of: isExpanded) { _, newValue in
            onExpansionChanged(newValue)
        }
    }

    private var popupWidth: CGFloat {
        switch textSize {
        case .small:
            return 372
        case .medium:
            return 392
        case .large:
            return 408
        }
    }

    private var primaryFont: Font {
        switch textSize {
        case .small:
            return .headline.weight(.semibold)
        case .medium:
            return .title3.weight(.semibold)
        case .large:
            return .title2.weight(.semibold)
        }
    }

    private var secondaryFont: Font {
        switch textSize {
        case .small:
            return .subheadline
        case .medium:
            return .body
        case .large:
            return .body.weight(.medium)
        }
    }

    private var expandedListFont: Font {
        switch textSize {
        case .small:
            return .subheadline
        case .medium:
            return .body
        case .large:
            return .body
        }
    }
}
