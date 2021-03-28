import Foundation
import SwiftUI

struct LicensesView: View {
  private let licenses: [License] = [
    .mit(
      name: "Composable Architecture",
      copyright: "2020 Point-Free, Inc.",
      url: URL(string: "https://github.com/pointfreeco/swift-composable-architecture")!
    ),
    .mit(
      name: "SDWebImage",
      copyright: "2009-2018 Olivier Poitrey rs@dailymotion.com",
      url: URL(string: "https://github.com/SDWebImage/SDWebImage")!
    )
  ]

  @Environment(\.openURL) private var openURL

  var body: some View {
    List(licenses, id: \.title) { license in
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text(license.title)
            .bold()
          Button(license.url.absoluteString) {
            openURL(license.url)
          }
          .font(.callout)
          .buttonStyle(PlainButtonStyle())
          .foregroundColor(.blue)
        }
        Text(license.terms)
          .font(.system(.footnote, design: .monospaced))
      }
      .padding([.top, .bottom], 8)
    }
    .navigationBarTitle("Acknowledgements")
  }
}

struct License {
  let title: String
  let terms: String
  let url: URL
}

extension License {
  static func mit(name: String, copyright: String, url: URL) -> License {
    License(
      title: name,
      terms:
        """
        MIT License

        Copyright (c) \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy \
        of this software and associated documentation files (the "Software"), to deal \
        in the Software without restriction, including without limitation the rights \
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is furnished \
        to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN \
        THE SOFTWARE.
        """,
      url: url
    )
  }
}
