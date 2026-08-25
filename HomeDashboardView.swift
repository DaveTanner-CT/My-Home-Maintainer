import SwiftUI
import UIKit

/// A tappable image that opens a full-screen viewer with pinch-to-zoom, pan,
/// double-tap zoom, and a one-tap close button.
struct ExpandablePhoto: View {
    let image: UIImage
    var height: CGFloat? = nil
    var fill: Bool = false
    var cornerRadius: CGFloat = 12

    @State private var showViewer = false

    var body: some View {
        Button {
            showViewer = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if fill {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                Label("Zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open photo full screen")
        .fullScreenCover(isPresented: $showViewer) {
            FullScreenPhotoViewer(image: image)
        }
    }
}

struct FullScreenPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ZoomingScrollView(image: image)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.62), in: Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
            .accessibilityLabel("Close photo")
        }
        .statusBarHidden(true)
    }
}

private struct ZoomingScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func didDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.1 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let point = gesture.location(in: imageView)
            let targetScale = min(3, scrollView.maximumZoomScale)
            let width = scrollView.bounds.width / targetScale
            let height = scrollView.bounds.height / targetScale
            let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}
