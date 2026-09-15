import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

/// Shared photo-source control used throughout My Home Keeper.
///
/// Important: this intentionally uses ONE immediate full-screen presentation.
/// Earlier versions used a confirmationDialog followed by a delayed sheet/fullScreenCover.
/// On long unsaved Forms (Fixture, Furniture, Device/Equipment), dismissing the dialog could
/// cause SwiftUI to rebuild/scroll the Form before the delayed picker presentation fired.
/// The result was exactly what users saw: the source popup closed, the Form jumped to the top,
/// and no camera/library UI appeared.
///
/// The source chooser, camera, and photo library now all live inside the same presentation.
struct PhotoSourceButton<Label: View>: View {
    let onPhoto: (Data) -> Void
    private let label: () -> Label

    init(onPhoto: @escaping (Data) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.onPhoto = onPhoto
        self.label = label
    }

    @State private var showPhotoFlow = false

    var body: some View {
        Button {
            showPhotoFlow = true
        } label: {
            label()
        }
        .fullScreenCover(isPresented: $showPhotoFlow) {
            PhotoSourceFlowView(
                onPhoto: { data in
                    onPhoto(data)
                    showPhotoFlow = false
                },
                onCancel: {
                    showPhotoFlow = false
                }
            )
        }
    }
}

private struct PhotoSourceFlowView: View {
    private enum Stage {
        case chooseSource
        case camera
        case library
    }

    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    @State private var stage: Stage = .chooseSource
    @State private var cameraAlertMessage: String?

    var body: some View {
        Group {
            switch stage {
            case .chooseSource:
                sourceChooser
            case .camera:
                CameraPhotoPicker(
                    onPhoto: onPhoto,
                    onCancel: { stage = .chooseSource }
                )
                .ignoresSafeArea()
            case .library:
                PhotoLibraryPicker(
                    onPhoto: onPhoto,
                    onCancel: { stage = .chooseSource }
                )
                .ignoresSafeArea()
            }
        }
        .alert("Camera Unavailable", isPresented: Binding(
            get: { cameraAlertMessage != nil },
            set: { if !$0 { cameraAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { cameraAlertMessage = nil }
        } message: {
            Text(cameraAlertMessage ?? "The camera is not available.")
        }
    }

    private var sourceChooser: some View {
        NavigationStack {
            List {
                Section {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            requestCameraAndPresentIfAllowed()
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }

                    Button {
                        stage = .library
                    } label: {
                        Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
                    }
                }

                Section {
                    Text("Choose how you want to add a photo. The image will return to the record you are currently creating or editing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private func requestCameraAndPresentIfAllowed() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraAlertMessage = "This device does not have an available camera."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            stage = .camera

        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    if granted {
                        stage = .camera
                    } else {
                        cameraAlertMessage = "Camera access is off. Enable Camera access for My Home Keeper in Settings to take photos in the app."
                    }
                }
            }

        case .denied, .restricted:
            cameraAlertMessage = "Camera access is off. Enable Camera access for My Home Keeper in Settings to take photos in the app."

        @unknown default:
            cameraAlertMessage = "The camera is currently unavailable."
        }
    }
}

struct CameraPhotoPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhoto: onPhoto, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onPhoto: (Data) -> Void
        private let onCancel: () -> Void
        private var hasFinished = false

        init(onPhoto: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onPhoto = onPhoto
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !hasFinished else { return }
            hasFinished = true
            DispatchQueue.main.async { [onCancel] in onCancel() }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard !hasFinished else { return }
            hasFinished = true

            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else {
                DispatchQueue.main.async { [onCancel] in onCancel() }
                return
            }

            DispatchQueue.main.async { [onPhoto] in onPhoto(data) }
        }
    }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhoto: onPhoto, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPhoto: (Data) -> Void
        private let onCancel: () -> Void
        private var hasFinished = false

        init(onPhoto: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onPhoto = onPhoto
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !hasFinished else { return }
            hasFinished = true

            guard let provider = results.first?.itemProvider else {
                DispatchQueue.main.async { [onCancel] in onCancel() }
                return
            }

            let imageType = UTType.image.identifier
            guard provider.hasItemConformingToTypeIdentifier(imageType) else {
                DispatchQueue.main.async { [onCancel] in onCancel() }
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: imageType) { [onPhoto, onCancel] data, _ in
                DispatchQueue.main.async {
                    if let data {
                        onPhoto(data)
                    } else {
                        onCancel()
                    }
                }
            }
        }
    }
}
