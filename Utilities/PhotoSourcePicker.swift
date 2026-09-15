import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

struct PhotoSourceButton<Label: View>: View {
    let onPhoto: (Data) -> Void
    private let label: () -> Label

    init(onPhoto: @escaping (Data) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.onPhoto = onPhoto
        self.label = label
    }

    @State private var showSourceOptions = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
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
                presentPhotoLibraryAfterDialogDismisses()
            }

            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker(isPresented: $showCamera) { data in
                onPhoto(data)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker(isPresented: $showPhotoLibrary) { data in
                onPhoto(data)
            }
            .ignoresSafeArea()
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
            // Let the confirmation dialog fully dismiss before presenting another controller.
            try? await Task.sleep(nanoseconds: 300_000_000)
            await requestCameraAndPresentIfAllowed()
        }
    }

    private func presentPhotoLibraryAfterDialogDismisses() {
        Task { @MainActor in
            // Present the library through its own UIKit controller instead of SwiftUI's
            // .photosPicker modifier. This is substantially more reliable when this
            // button lives inside an unsaved Form that is itself presented modally.
            try? await Task.sleep(nanoseconds: 300_000_000)
            showPhotoLibrary = true
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
            showCamera = true

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                showCamera = true
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
    @Binding var isPresented: Bool
    let onPhoto: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPhoto: onPhoto)
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
        private var isPresented: Binding<Bool>
        private let onPhoto: (Data) -> Void
        private var hasFinished = false

        init(isPresented: Binding<Bool>, onPhoto: @escaping (Data) -> Void) {
            self.isPresented = isPresented
            self.onPhoto = onPhoto
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finishPresentation()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard !hasFinished else { return }
            hasFinished = true

            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
                onPhoto(data)
            }

            DispatchQueue.main.async { [weak self] in
                self?.isPresented.wrappedValue = false
            }
        }

        private func finishPresentation() {
            guard !hasFinished else { return }
            hasFinished = true
            DispatchQueue.main.async { [weak self] in
                self?.isPresented.wrappedValue = false
            }
        }
    }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPhoto: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPhoto: onPhoto)
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
        private var isPresented: Binding<Bool>
        private let onPhoto: (Data) -> Void
        private var hasFinished = false

        init(isPresented: Binding<Bool>, onPhoto: @escaping (Data) -> Void) {
            self.isPresented = isPresented
            self.onPhoto = onPhoto
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !hasFinished else { return }
            hasFinished = true

            guard let provider = results.first?.itemProvider else {
                dismiss()
                return
            }

            let imageType = UTType.image.identifier
            guard provider.hasItemConformingToTypeIdentifier(imageType) else {
                dismiss()
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: imageType) { [weak self] data, _ in
                guard let self else { return }

                if let data {
                    DispatchQueue.main.async {
                        self.onPhoto(data)
                        self.isPresented.wrappedValue = false
                    }
                } else {
                    self.dismiss()
                }
            }
        }

        private func dismiss() {
            DispatchQueue.main.async { [weak self] in
                self?.isPresented.wrappedValue = false
            }
        }
    }
}
