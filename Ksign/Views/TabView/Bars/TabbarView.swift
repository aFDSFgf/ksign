//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI
import NimbleViews

struct TabbarView: View {
@State private var selectedTab: TabEnum = .sources

var body: some View {
TabView(selection: $selectedTab) {
ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
TabEnum.view(for: tab)
.tabItem {
Label(tab.title, systemImage: tab.icon)
}
.tag(tab)
}
}
.toolbarBackground(.ultraThinMaterial, for: .tabBar)
.toolbarBackground(.visible, for: .tabBar)
.toolbarColorScheme(.dark, for: .tabBar)
.background(KsignBackground())
}
}
