//
//  MeasureSizeModifier.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 03.12.2024.
//

import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: geometry.size)
                }
            }
    }
}

extension View {
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        modifier(MeasureSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

private struct Measurements: View {
    let showSize: Bool
    let color: Color
    @State private var size: CGSize = .zero

    var body: some View {
        label.measureSize { size = $0 }
    }

    var label: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .strokeBorder(color, lineWidth: 1)

            Text("H:\(size.height.formatted) W:\(size.width.formatted)")
                .foregroundColor(.black)
                .font(.system(size: 8))
                .opacity(showSize ? 1 : 0)
        }
    }
}

extension View {
    func measured(_ showSize: Bool = true, _ color: Color = Color.red) -> some View {
        overlay(Measurements(showSize: showSize, color: color))
    }
}

private extension CGFloat {
    var formatted: String {
        abs(remainder(dividingBy: 1)) <= 0.001
            ? .init(format: "%.0f", self)
            : .init(format: "%.2f", self)
    }
}

private extension Double {
    var formatted: String {
        CGFloat(self).formatted
    }
}

public extension Color {
    static var random: Color {
        Color(
            red: .random(in: 0 ... 1.0),
            green: .random(in: 0 ... 1.0),
            blue: .random(in: 0 ... 1.0)
        )
    }
}

public extension View {
    @ViewBuilder
    func randomBackgroundColor() -> some View {
        background(Color.random)
    }
}
