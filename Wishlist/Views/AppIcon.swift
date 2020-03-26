//
//  AppIcon.swift
//  Wishlist
//
//  Created by Ryan Davis on 27/3/20.
//  Copyright © 2020 Ryan Davis. All rights reserved.
//

import SwiftUI
import URLImage

struct AppIcon: View {
  let url: URL
  let width: CGFloat

  init(_ url: URL, width: CGFloat) {
    self.url = url
    self.width = width
  }

  var body: some View {
    URLImage(
      url,
      delay: 0.25,
      processors: [
        Resize(size: CGSize(width: width, height: width), scale: UIScreen.main.scale)
      ],
      content: {
        $0.image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .clipShape(RoundedRectangle(cornerRadius: self.width * 0.2237))
      }
    ).frame(width: width, height: width)
  }
}
