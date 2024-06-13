//
//  ContentView.swift
//  sendPhoto
//
//  Created by Adrian on 5/27/24.
//

import SwiftUI

import Network

struct imgPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: imgPicker

        init(parent: imgPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary //change to .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        
    }
}

struct ContentView: View {
    @State private var showingImagePicker = false
    @State private var presentedImage: UIImage?
    @State private var numPackages = 0
    
    @State private var compressionQuality = 0.5
    
    func sendTCPMessage(image: UIImage) {
        let host = NWEndpoint.Host("127.0.0.1")
        let port = NWEndpoint.Port(integerLiteral: 4200)
        
        let connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected to \(host)")
                let imageData = image.jpegData(compressionQuality: compressionQuality) ?? Data()
                var transmission = withUnsafeBytes(of: UInt32(imageData.count).bigEndian, Array.init)
                transmission.append(contentsOf: imageData)
                connection.send(content: transmission, completion: .contentProcessed({ sendError in
                    if let error = sendError {
                        print("Send error: \(error)")
                    } else {
                        print("Message sent")
                        receiveAcknowledgment(connection: connection)
                    }
                }))
            case .failed(let error):
                print("Connection failed: \(error)")
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }

    func receiveAcknowledgment(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 3) { data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                if let ack = String(data: data, encoding: .utf8) {
                    numPackages += 1
                    if ack == "ack" {
                        receiveAcknowledgment(connection: connection)
                    }
                }
            } else if let error = error {
                print("Receive error: \(error)")
                connection.cancel()
            }
        }
    }
    
    
    var body: some View {
        VStack (spacing: 20) {
            Spacer()
            Button("Select Image") {
                showingImagePicker = true
            }
            .sheet(isPresented: $showingImagePicker) {
                imgPicker(selectedImage: $presentedImage)
            }
            if let image = presentedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            } else {
                Text("No Image Selected")
                    .frame(width: 300, height: 300)
                    .background(Color.gray)
                    .foregroundColor(.white)
            }
            VStack(spacing:0) {
                Slider(value: $compressionQuality, in: 0...1)
                    .padding()
                Text(String(format: "%.2f", compressionQuality))
                Text("Compression quality (1 = no compression)")
            }
            HStack(spacing: 30) {
                Button("Send via TCP") {
                    numPackages = 0 
                    if presentedImage != nil {
                        sendTCPMessage(image: presentedImage!)
                    }
                }.padding(25)
            }
            if numPackages > 0 {
                Text("\(numPackages) packages successfully delivered")
            }
            Spacer()
        }.onChange(of: presentedImage) { newValue in
            print("change in image")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
