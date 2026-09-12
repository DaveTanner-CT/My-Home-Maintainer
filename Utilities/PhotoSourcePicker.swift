import SwiftUI
import PhotosUI
import UIKit

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
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        Button {
            showSourceOptions = true
        } label: {
            label()
        }
        .confirmationDialog("Add Photo", isPresented: $showSourceOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Photo Library") { showPhotoLibrary = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showCamera) {
            CameraPhotoPicker { data in
                onPhoto(data)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run { onPhoto(data) }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
    }
}

struct CameraPhotoPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhoto: onPhoto, dismiss: dismiss)
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
        let onPhoto: (Data) -> Void
        let dismiss: DismissAction

        init(onPhoto: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onPhoto = onPhoto
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { dismiss() }
            guard let image = info[.originalImage] as? UIImage else { return }
            if let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
                onPhoto(data)
            }
        }
    }
}
