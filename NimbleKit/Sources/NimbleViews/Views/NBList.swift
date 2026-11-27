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
            Color(red: 0.018, green: 0.023, blue: 0.034)

            Canvas { context, size in
                // A subdued woven carbon-fiber texture under the traces.
                let tile: CGFloat = 12
                for row in 0..<Int(ceil(size.height / tile)) {
                    for column in 0..<Int(ceil(size.width / tile)) {
                        let x = CGFloat(column) * tile
                        let y = CGFloat(row) * tile
                        let horizontal = (row + column).isMultiple(of: 2)
                        let rect = CGRect(x: x, y: y, width: tile, height: tile)
                        context.fill(Path(rect), with: .color(.white.opacity(horizontal ? 0.018 : 0.006)))
                        var weave = Path()
                        for offset in stride(from: CGFloat(1), through: tile - 1, by: 3) {
                            if horizontal {
                                weave.move(to: CGPoint(x: x, y: y + offset))
                                weave.addLine(to: CGPoint(x: x + tile, y: y + offset))
                            } else {
                                weave.move(to: CGPoint(x: x + offset, y: y))
                                weave.addLine(to: CGPoint(x: x + offset, y: y + tile))
                            }
                        }
                        context.stroke(weave, with: .color(.white.opacity(0.023)), lineWidth: 0.5)
                    }
                }

                let colors: [Color] = [.cyan, .blue, .indigo, .purple, .pink]
                // Mirrored banks of angled PCB traces leave the center readable.
                for side in 0..<2 {
                    for index in 0..<24 {
                        let y = size.height * (CGFloat(index) + 0.4) / 24
                        let direction: CGFloat = side == 0 ? 1 : -1
                        let edge: CGFloat = side == 0 ? 0 : size.width
                        let reach = size.width * (0.16 + CGFloat(index % 6) * 0.035)
                        let offset: CGFloat = CGFloat((index % 5) - 2) * 8
                        let end = CGPoint(x: edge + direction * reach, y: y + offset + 22)
                        var trace = Path()
                        trace.move(to: CGPoint(x: edge, y: y))
                        trace.addLine(to: CGPoint(x: edge + direction * (reach * 0.30), y: y))
                        trace.addLine(to: CGPoint(x: edge + direction * (reach * 0.52), y: y + offset))
                        trace.addLine(to: CGPoint(x: edge + direction * (reach * 0.72), y: y + offset))
                        trace.addLine(to: end)
                        if index.isMultiple(of: 2) {
                            trace.move(to: CGPoint(x: edge + direction * (reach * 0.52), y: y + offset))
                            trace.addLine(to: CGPoint(x: edge + direction * (reach * 0.65), y: y + offset - 14))
                            trace.addLine(to: CGPoint(x: edge + direction * (reach * 0.85), y: y + offset - 14))
                        }
                        let color = colors[(index + side) % colors.count]
                        var glow = context
                        glow.addFilter(.shadow(color: color.opacity(0.7), radius: 5))
                        glow.stroke(trace, with: .color(color.opacity(0.31)), lineWidth: 1.1)
                        context.stroke(trace, with: .color(color.opacity(0.28)), lineWidth: 0.55)
                        let via = CGRect(x: end.x - 1.8, y: end.y - 1.8, width: 3.6, height: 3.6)
                        glow.stroke(Path(ellipseIn: via), with: .color(color.opacity(0.55)), lineWidth: 0.8)
                    }
                }
            }

            RadialGradient(
                colors: [.clear, .black.opacity(0.08), .black.opacity(0.52)],
                center: .center,
                startRadius: 30,
                endRadius: 550
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
