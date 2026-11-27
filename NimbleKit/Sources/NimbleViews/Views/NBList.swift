//
//  NBList.swift
//  NimbleKit
//
//  Created by samara on 7.05.2025.
//

import SwiftUI

public struct KsignBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.024, blue: 0.04)
            LinearGradient(
                colors: [.blue.opacity(0.12), .clear, .purple.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                var grid = Path()
                for x in stride(from: CGFloat.zero, through: size.width, by: 28) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat.zero, through: size.height, by: 28) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.025)), lineWidth: 0.5)

                let colors: [Color] = [.cyan, .blue, .indigo, .purple, .pink]
                for index in 0..<8 {
                    let y = size.height * (CGFloat(index) + 0.5) / 8
                    let reach = size.width * (0.14 + CGFloat(index % 3) * 0.035)
                    let bend: CGFloat = 18
                    let color = colors[index % colors.count]
                    var traces = Path()
                    traces.move(to: CGPoint(x: 0, y: y))
                    traces.addLine(to: CGPoint(x: reach - bend, y: y))
                    traces.addLine(to: CGPoint(x: reach, y: y + bend))
                    traces.addLine(to: CGPoint(x: reach, y: y + bend + 25))
                    traces.move(to: CGPoint(x: size.width, y: size.height - y))
                    traces.addLine(to: CGPoint(x: size.width - reach + bend, y: size.height - y))
                    traces.addLine(to: CGPoint(x: size.width - reach, y: size.height - y - bend))
                    traces.addLine(to: CGPoint(x: size.width - reach, y: size.height - y - bend - 25))
                    var glow = context
                    glow.addFilter(.shadow(color: color.opacity(0.8), radius: 6))
                    glow.stroke(traces, with: .color(color.opacity(0.35)), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
    }
}

public struct NBList<Content>: View where Content: View {
    public enum NBListType {
        case list
        case form
    }

    private var _title: String
    private var _mode: NavigationBarItem.TitleDisplayMode
    private var _type: NBListType
    private var _content: Content

    public init(
        _ title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        type: NBListType = .form,
        @ViewBuilder content: () -> Content
    ) {
        self._title = title
        self._mode = displayMode
        self._type = type
        self._content = content()
    }

    public var body: some View {
        Group {
            switch _type {
            case .form:
                Form {
                    _content
                }
            case .list:
                List {
                    _content
                }
            }
        }
        .navigationTitle(_title)
        .navigationBarTitleDisplayMode(_mode)
        .scrollContentBackground(.hidden)
        .background(KsignBackground())
    }
}
