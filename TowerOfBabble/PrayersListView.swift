//
//  PrayersListView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/4/25.
//

import SwiftUI

struct PrayersListView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @State private var showingEditor = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Prayer list
                if prayerManager.prayers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No prayers yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Tap + to create your first prayer")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(prayerManager.prayers) { prayer in
                            NavigationLink(destination: PrayerEditorView(prayer: prayer)) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(prayer.title)
                                        .font(.headline)
                                    Text(prayer.text)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .onDelete(perform: deletePrayers)
                    }
                }
                
                // Floating + button at bottom
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingEditor = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("My Prayers")
            .sheet(isPresented: $showingEditor) {
                PrayerEditorView(prayer: nil)
            }
        }
    }
    
    private func deletePrayers(at offsets: IndexSet) {
        for index in offsets {
            let prayer = prayerManager.prayers[index]
            prayerManager.deletePrayer(prayer)
        }
    }
}
