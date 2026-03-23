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
    let greeting: String
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
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(greeting)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(chipBackgroundColor, in: Capsule())

                    Text("KeepingUp")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(secondaryTextColor)
                            .frame(width: 16, height: 16)
                            .background(.white.opacity(0.001))
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }

                Text(primaryMessage)
                    .font(primaryFont)
                    .foregroundStyle(primaryTextColor)
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
                                .foregroundStyle(secondaryTextColor)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(secondaryTextColor)
                                .padding(.top, 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(isExpanded ? "Hide open task preview" : "Show open task preview")
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(tasks.prefix(5))) { task in
                        Label {
                            Text(task.title)
                                .font(expandedListFont)
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Circle()
                                .fill(secondaryTextColor.opacity(0.6))
                                .frame(width: 5, height: 5)
                        }
                        .labelStyle(.titleAndIcon)
                    }

                    if tasks.count > 5 {
                        Text("+ \(tasks.count - 5) more in menu bar")
                            .font(secondaryFont)
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                .padding(.top, isExpanded ? 4 : 0)
                .frame(maxHeight: isExpanded ? 140 : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(width: popupWidth, alignment: .leading)
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var primaryTextColor: Color {
        Color(nsColor: .labelColor)
    }

    private var secondaryTextColor: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    private var chipBackgroundColor: Color {
        Color(nsColor: .separatorColor).opacity(0.12)
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        Color(nsColor: .separatorColor).opacity(0.35)
    }
}
