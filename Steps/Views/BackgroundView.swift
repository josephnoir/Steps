//
//  BackgroundView.swift
//  Steps
//
//  Created by Raphael on 04.10.23.
//

import SwiftUI

struct BackgroundView: View {
    let backgroundImageState: StepsViewModel.BackgroundImageState
    
    var body: some View {
        switch backgroundImageState {
        case .success(let image):
            image
                .resizable()
        case .loading:
            ProgressView()
        case .empty:
            Image("background")
                .resizable()
        case .failure:
            // The settings view will show an alert. We just set
            // the default background as a fallback.
            Image("background")
                .resizable()
        }
    }
}
