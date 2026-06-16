import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("usuarioGuardado") private var username = ""
    @AppStorage("passwordGuardada") private var password = ""
    @AppStorage("tipoConexion") private var tipoConexion = 0 // 0 = Local, 1 = Externo
    
    // Tus URLs exactas guardadas por defecto
    @AppStorage("urlLocal") private var urlLocal = "http://0.0.0.0:0"
    @AppStorage("urlExterna") private var urlExterna = "https://yourdomain.com"
    
    @State private var isLoggedIn = false
    @State private var authToken = ""
    @State private var urlBaseActiva = ""
    
    func conectarFilebrowser() async {
        var urlBase = tipoConexion == 0 ? urlLocal : urlExterna
        if urlBase.hasSuffix("/") { urlBase.removeLast() }
        
        guard let url = URL(string: "\(urlBase)/api/login") else { return }
        
        let payload = LoginPayload(username: username, password: password)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let token = String(data: data, encoding: .utf8) ?? ""
                // Transición animada suave hacia el servidor
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.authToken = token
                    self.urlBaseActiva = urlBase
                    self.isLoggedIn = true
                }
            } else {
                print("Error de autenticación")
            }
        } catch {
            print("Error de red: \(error.localizedDescription)")
        }
    }
    
    var body: some View {
        // ZStack permite que las animaciones de transición se deslicen correctamente
        ZStack {
            if isLoggedIn {
                NavigationView {
                    NubeView(token: authToken, currentPath: "/", baseURL: urlBaseActiva) {
                        // Transición animada suave al salir al Log-in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            self.isLoggedIn = false
                            self.authToken = ""
                        }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "server.rack")
                        .resizable().scaledToFit().frame(width: 80, height: 80).foregroundStyle(.blue)
                    Text("TheAlejoCloud").font(.largeTitle).fontWeight(.bold)
                    
                    Picker("Entorno", selection: $tipoConexion) {
                        Text("Red Local").tag(0)
                        Text("Externo").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    DisclosureGroup("⚙️ Configuración de Servidores") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("URL Local:").font(.caption).foregroundColor(.gray)
                            TextField("http://...", text: $urlLocal)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                            
                            Text("URL Externa:").font(.caption).foregroundColor(.gray)
                            TextField("https://...", text: $urlExterna)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.top, 5)
                    }
                    .padding(.horizontal, 5)
                    
                    VStack(spacing: 15) {
                        TextField("Usuario", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                        SecureField("Contraseña", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 5)
                    
                    Button(action: { Task { await conectarFilebrowser() } }) {
                        Text("Conectar al Servidor")
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(12)
                    }
                    Spacer()
                }
                .padding(30)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
}

struct NubeView: View {
    var token: String
    var currentPath: String
    var baseURL: String
    var alCerrarSesion: () -> Void
    
    @State private var archivos: [FBItem] = []
    @State private var estaCargando = true
    @State private var mostrarSelectorArchivos = false
    
    // Estados para la Descarga Múltiple e Individual
    @State private var modoSeleccionActive = false
    @State private var itemsSeleccionados = Set<String>() // Almacena las rutas de los archivos marcados
    @State private var descargando = false
    @State private var mostrarShareSheet = false
    @State private var archivosDescargadosURLs: [URL] = [] // Ahora soporta múltiples URLs locales
    
    func cargarArchivos() async {
        let rutaSegura = currentPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? currentPath
        guard let url = URL(string: "\(baseURL)/api/resources\(rutaSegura)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let respuesta = try JSONDecoder().decode(FilebrowserResponse.self, from: data)
                await MainActor.run {
                    self.archivos = respuesta.items ?? []
                    self.estaCargando = false
                }
            }
        } catch {
            await MainActor.run { self.estaCargando = false }
        }
    }
    
    func subirArchivo(urlLocal: URL) async {
        guard urlLocal.startAccessingSecurityScopedResource() else { return }
        defer { urlLocal.stopAccessingSecurityScopedResource() }
        
        guard let datosArchivo = try? Data(contentsOf: urlLocal) else { return }
        let nombreArchivo = urlLocal.lastPathComponent
        
        var rutaBase = currentPath
        if !rutaBase.hasSuffix("/") { rutaBase += "/" }
        let rutaDestino = "\(rutaBase)\(nombreArchivo)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "\(baseURL)/api/resources\(rutaDestino)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        
        do {
            let (_, response) = try await URLSession.shared.upload(for: request, from: datosArchivo)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                await cargarArchivos()
            }
        } catch {
            print("Error al subir")
        }
    }
    
    // Función optimizada para descargar múltiples archivos uno tras otro de forma limpia
    func descargarArchivosSeleccionados() async {
        await MainActor.run {
            self.descargando = true
            self.archivosDescargadosURLs.removeAll()
        }
        
        let fileManager = FileManager.default
        // Buscamos los archivos reales que corresponden a las rutas seleccionadas
        let pathsADescargar = archivos.filter { itemsSeleccionados.contains($0.path) && !$0.isDir }
        
        for item in pathsADescargar {
            let rutaSegura = item.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.path
            guard let url = URL(string: "\(baseURL)/api/raw\(rutaSegura)") else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(token, forHTTPHeaderField: "X-Auth")
            
            do {
                let (tempURL, response) = try await URLSession.shared.download(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(item.name)
                    
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try? fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.moveItem(at: tempURL, to: destinationURL)
                    
                    await MainActor.run {
                        self.archivosDescargadosURLs.append(destinationURL)
                    }
                }
            } catch {
                print("Error descargando item individual: \(item.name)")
            }
        }
        
        await MainActor.run {
            self.descargando = false
            if !self.archivosDescargadosURLs.isEmpty {
                self.mostrarShareSheet = true
                self.modoSeleccionActive = false
                self.itemsSeleccionados.removeAll()
            }
        }
    }
    
    // Función auxiliar para un solo archivo (toque rápido fuera de selección múltiple)
    func descargarUnSoloArchivo(archivo: FBItem) async {
        await MainActor.run {
            self.descargando = true
            self.archivosDescargadosURLs.removeAll()
        }
        
        let rutaSegura = archivo.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? archivo.path
        guard let url = URL(string: "\(baseURL)/api/raw\(rutaSegura)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        
        do {
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let fileManager = FileManager.default
                let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(archivo.name)
                
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try? fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempURL, to: destinationURL)
                
                await MainActor.run {
                    self.archivosDescargadosURLs = [destinationURL]
                    self.descargando = false
                    self.mostrarShareSheet = true
                }
            } else {
                await MainActor.run { self.descargando = false }
            }
        } catch {
            await MainActor.run { self.descargando = false }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if estaCargando {
                Spacer()
                ProgressView("Cargando elementos...")
                Spacer()
            } else if archivos.isEmpty {
                Spacer()
                Text("Carpeta vacía").foregroundColor(.gray)
                Spacer()
            } else {
                // SOLUCIÓN AL BLOQUE GRUPAL: Cambiamos List por ScrollView + LazyVStack nativo
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(archivos) { archivo in
                            HStack(spacing: 12) {
                                // Si está activo el modo selección y es archivo, mostramos checkbox
                                if modoSeleccionActive && !archivo.isDir {
                                    Image(systemName: itemsSeleccionados.contains(archivo.path) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(itemsSeleccionados.contains(archivo.path) ? .blue : .gray)
                                        .font(.title3)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                }
                                
                                if archivo.isDir {
                                    // Navegación limpia de carpetas individuales
                                    NavigationLink(destination: NubeView(token: token, currentPath: archivo.path, baseURL: baseURL, alCerrarSesion: alCerrarSesion)) {
                                        FilaArchivo(archivo: archivo)
                                    }
                                    .disabled(modoSeleccionActive) // Deshabilitar entrar si estamos seleccionando archivos
                                } else {
                                    // Acción sobre archivos individuales
                                    FilaArchivo(archivo: archivo)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if modoSeleccionActive {
                                                if itemsSeleccionados.contains(archivo.path) {
                                                    itemsSeleccionados.remove(archivo.path)
                                                } else {
                                                    itemsSeleccionados.insert(archivo.path)
                                                }
                                            } else {
                                                Task { await descargarUnSoloArchivo(archivo: archivo) }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            // Efecto visual individual al tocar cada fila
                            .background(Color(UIColor.systemBackground))
                            
                            Divider().padding(.leading, 72) // Separación elegante e individual estilo iOS
                        }
                    }
                }
            }
            
            // Barra inferior emergente que se activa al seleccionar múltiples archivos
            if modoSeleccionActive && !itemsSeleccionados.isEmpty {
                VStack {
                    Divider()
                    Button(action: { Task { await descargarArchivosSeleccionados() } }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square.fill")
                            Text("Descargar seleccionados (\(itemsSeleccionados.count))")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(15)
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle(currentPath == "/" ? "Home" : URL(fileURLWithPath: currentPath).lastPathComponent)
        .toolbar {
            // LADO IZQUIERDO: Cerrar Sesión (Solo en el directorio Home)
            ToolbarItem(placement: .navigationBarLeading) {
                if currentPath == "/" && !modoSeleccionActive {
                    Button(action: alCerrarSesion) {
                        Text("Cerrar Sesión").foregroundColor(.red).fontWeight(.medium)
                    }
                }
            }
            
            // LADO DERECHO: Botones de Acción Múltiple y Subida (+)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !archivos.isEmpty {
                    Button(action: {
                        withAnimation {
                            modoSeleccionActive.toggle()
                            itemsSeleccionados.removeAll()
                        }
                    }) {
                        Text(modoSeleccionActive ? "Cancelar" : "Seleccionar")
                            .fontWeight(.medium)
                    }
                }
                
                if !modoSeleccionActive {
                    Button(action: { mostrarSelectorArchivos = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .fileImporter(isPresented: $mostrarSelectorArchivos, allowedContentTypes: [.data]) { resultado in
            switch resultado {
            case .success(let urlArchivo): Task { await subirArchivo(urlLocal: urlArchivo) }
            case .failure(let error): print("Error: \(error)")
            }
        }
        .task { await cargarArchivos() }
        .overlay {
            if descargando {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 15) {
                        ProgressView().scaleEffect(1.5).tint(.blue)
                        Text("Procesando Descarga...").font(.headline)
                    }
                    .padding(30).background(Color(UIColor.systemBackground)).cornerRadius(15).shadow(radius: 10)
                }
            }
        }
        .sheet(isPresented: $mostrarShareSheet) {
            if !archivosDescargadosURLs.isEmpty {
                ShareSheet(items: archivosDescargadosURLs) // Comparte la lista completa de archivos descargados
            }
        }
    }
}

struct FilaArchivo: View {
    var archivo: FBItem
    var body: some View {
        HStack {
            Image(systemName: archivo.isDir ? "folder.fill" : "doc.text.fill")
                .foregroundColor(archivo.isDir ? .blue : .gray)
                .font(.title2).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(archivo.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if !archivo.isDir, let size = archivo.size {
                    Text("\(size / 1024) KB").font(.caption).foregroundColor(.gray)
                }
            }
            Spacer()
            if archivo.isDir {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Estructuras de datos (DTOs)
struct LoginPayload: Codable { let username, password: String }
struct FilebrowserResponse: Codable { let items: [FBItem]? }
struct FBItem: Codable, Identifiable {
    var id: String { path }
    let name, path: String
    let isDir: Bool
    let size: Int64?
}

#Preview {
    ContentView()
}
