import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

private enum PhotoPickerDestination: String, Identifiable {
    case camera
    case library

    var id: String { rawValue }
}

struct PhotoSourceButton<Label: View>: View {
    let onPhoto: (Data) -> Void
    private let label: () -> Label

    init(onPhoto: @escaping (Data) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.onPhoto = onPhoto
        self.label = label
    }

    @State private var showSourceOptions = false
    @State private var activePicker: PhotoPickerDestination?
    @State private var cameraAlertMessage: String?

    var body: some View {
        Button {
            showSourceOptions = true
        } label: {
            label()
        }
        .confirmationDialog("Add Photo", isPresented: $showSourceOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    presentCameraAfterDialogDismisses()
                }
            }

            Button("Choose from Photo Library") {
                presentLibraryAfterDialogDismisses()
            }

            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(item: $activePicker) { destination in
            switch destination {
            case .camera:
                CameraPhotoPicker(
                    onPhoto: { data in
                        onPhoto(data)
                        activePicker = nil
                    },
                    onCancel: {
                        activePicker = nil
                    }
                )
                .ignoresSafeArea()

            case .library:
                PhotoLibraryPicker(
                    onPhoto: { data in
                        onPhoto(data)
                        activePicker = nil
                    },
                    onCancel: {
                        activePicker = nil
                    }
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

    private func presentCameraAfterDialogDismisses() {
        Task { @MainActor in
            // Allow the confirmation dialog to finish dismissing before requesting
            // another presentation from a form that may itself already be in a sheet.
            try? await Task.sleep(nanoseconds: 350_000_000)
            await requestCameraAndPresentIfAllowed()
        }
    }

    private func presentLibraryAfterDialogDismisses() {
        Task { @MainActor in
            // Camera and library deliberately share ONE fullScreenCover. Two competing
            // fullScreenCover modifiers on this row caused presentation failures in
            // unsaved Add/Edit forms that are already displayed as sheets.
            try? await Task.sleep(nanoseconds: 350_000_000)
            activePicker = .library
        }
    }

    @MainActor
    private func requestCameraAndPresentIfAllowed() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraAlertMessage = "This device does not have an available camera."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            activePicker = .camera

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                activePicker = .camera
            } else {
                cameraAlertMessage = "Camera access is off. Enable Camera access for My Home Keeper in Settings to take photos in the app."
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
