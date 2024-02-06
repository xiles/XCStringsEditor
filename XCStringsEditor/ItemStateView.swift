//
//  ItemStateView.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/4/24.
//

import SwiftUI

struct ItemStateView: View {
    var state: LocalizeItem.State
    
    struct BadgeModifier: ViewModifier {
        var color: Color
        
        func body(content: Content) -> some View {
            content
                .font(.system(size: 8, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color, lineWidth: 1.0)
                        .fill(color.opacity(0.2))
                )
        }
    }
    
    var body: some View {
        switch state {
        case .translateLater:
            Text("LATER")
                .modifier(BadgeModifier(color: .gray))
        case .needsWork:
            Text("NEEDS WORK")
                .modifier(BadgeModifier(color: .orange))
        case .new:
            Text("NEW")
                .modifier(BadgeModifier(color: .red))
        case .needsReview:
            Text("NEEDS REVIEW")
                .modifier(BadgeModifier(color: .orange))
        case .stale:
            Text("STALE")
                .modifier(BadgeModifier(color: .yellow))
        case .translated:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    VStack {
        ItemStateView(state: .new)
        ItemStateView(state: .needsReview)
        ItemStateView(state: .translateLater)
        ItemStateView(state: .stale)
        ItemStateView(state: .translated)
    }
    .padding()
}
