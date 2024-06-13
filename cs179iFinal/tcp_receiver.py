

import socket
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True
import io

my_ip = "127.0.0.1"
my_port = 4200
my_addr = (my_ip, my_port)

receiver_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
receiver_socket.bind(my_addr)
receiver_socket.listen(1)

print("Waiting for incoming connection...")
conn_socket, conn_addr = receiver_socket.accept()
print(f"Connected to {conn_addr}")

received_data = b""
expected_data_length = None

while True:
    try:
        data = conn_socket.recv(1024)
        if not data:
            break
        
        received_data += data
        
        if expected_data_length is None and len(received_data) >= 4:
            expected_data_length = int.from_bytes(received_data[:4], byteorder='big')
            received_data = received_data[4:]
            print(f"Expected size: {expected_data_length} bytes")

        if expected_data_length is not None and len(received_data) >= expected_data_length: #upon completion
            image_data = received_data[:expected_data_length]
            received_data = received_data[expected_data_length:]
            
            image_stream = io.BytesIO(image_data)
            try:
                image = Image.open(image_stream)
                image.save("reconstructed.png")
                image.show()
                print("Image saved successfully")
                received_data = b""
                expected_data_length = None
                
            except Image.UnidentifiedImageError:
                print("Failed to identify image")
            
            print("Receiving finished")
            break

        conn_socket.sendall("ack".encode())
        
    except KeyboardInterrupt:
        print("Receiving finished")
        break

receiver_socket.close()
conn_socket.close()
