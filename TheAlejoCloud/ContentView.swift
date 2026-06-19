import SwiftUI
import UniformTypeIdentifiers

// MARK: - Wrapper para exportar archivos nativamente
struct DownloadedFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .zip, .archive] }
    var fileURL: URL
    
    init(fileURL: URL) { self.fileURL = fileURL }
    init(configuration: ReadConfiguration) throws { fatalError("Solo soporte de escritura") }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: fileURL, options: .immediate)
    }
}

// MARK: - Manejo de Tema
enum AppTheme: Int, CaseIterable {
    case automatic = 0
    case light = 1
    case dark = 2
    
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Vista Principal
struct ContentView: View {
    @AppStorage("usuarioGuardado") private var username = ""
    @AppStorage("passwordGuardada") private var password = ""
    @AppStorage("tipoConexion") private var tipoConexion = 0
    
    @AppStorage("urlLocal") private var urlLocal = "http://0.0.0.0:0"
    @AppStorage("urlExterna") private var urlExterna = "https://yourdomain.com"
    
    @AppStorage("isAutoTheme") private var isAutoTheme = true
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var systemColorScheme
    
    @State private var isLoggedIn = false
    @State private var authToken = ""
    @State private var urlBaseActiva = ""
    
    @State private var isLoadingLogin = false
    @State private var errorMensaje = ""
    
    var isCurrentlyDark: Bool {
        isAutoTheme ? systemColorScheme == .dark : isDarkMode
    }
    
    func conectarFilebrowser() async {
        isLoadingLogin = true
        errorMensaje = ""
        
        var urlBase = tipoConexion == 0 ? urlLocal : urlExterna
        if urlBase.hasSuffix("/") { urlBase.removeLast() }
        
        guard let url = URL(string: "\(urlBase)/api/login") else {
            isLoadingLogin = false
            errorMensaje = "URL Inválida"
            return
        }
        
        let payload = LoginPayload(username: username, password: password)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let token = String(data: data, encoding: .utf8) ?? ""
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.authToken = token
                    self.urlBaseActiva = urlBase
                    self.isLoggedIn = true
                }
            } else {
                withAnimation { errorMensaje = "Credenciales incorrectas" }
            }
        } catch {
            withAnimation { errorMensaje = "Error de red: \(error.localizedDescription)" }
        }
        isLoadingLogin = false
    }
    
    func alCerrarSesion() {
        withAnimation(.easeInOut(duration: 0.4)) {
            self.isLoggedIn = false
            self.authToken = ""
        }
    }
    
    var body: some View {
        ZStack {
            (isCurrentlyDark ? Color(white: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.98))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: isCurrentlyDark)
            
            if isLoggedIn {
                NavigationView {
                    NubeView(token: authToken, initialPath: "/", baseURL: urlBaseActiva, isDark: isCurrentlyDark, alCerrarSesion: alCerrarSesion)
                }
                .navigationViewStyle(.stack)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        Spacer().frame(height: 30)
                        
                        Image(systemName: "server.rack")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.blue.gradient)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("TheAlejoCloud")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(isCurrentlyDark ? .white : .black)
                            .animation(.easeInOut(duration: 0.6), value: isCurrentlyDark)
                        
                        VStack(spacing: 20) {
                            HStack {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.6)) { isAutoTheme.toggle() }
                                }) {
                                    HStack {
                                        Image(systemName: isAutoTheme ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isAutoTheme ? .blue : .gray)
                                            .font(.title3)
                                        Text("Auto")
                                            .foregroundColor(isCurrentlyDark ? .white : .black)
                                    }
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("Claro").font(.caption).foregroundColor(.gray)
                                    Toggle("", isOn: Binding(
                                        get: { isCurrentlyDark },
                                        set: { newValue in
                                            withAnimation(.easeInOut(duration: 0.6)) {
                                                isAutoTheme = false
                                                isDarkMode = newValue
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(.blue)
                                    Text("Oscuro").font(.caption).foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 10)
                            
                            Picker("Entorno", selection: $tipoConexion) {
                                Text("Red Local").tag(0)
                                Text("Externo").tag(1)
                            }
                            .pickerStyle(.segmented)
                            
                            DisclosureGroup("⚙️ Configuración de Servidores") {
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("http://...", text: $urlLocal)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                    TextField("https://...", text: $urlExterna)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                }
                                .padding(.top, 5)
                            }
                            .padding()
                            .background(isCurrentlyDark ? Color(white: 0.15) : Color.white)
                            .cornerRadius(12)
                            .animation(.easeInOut(duration: 0.6), value: isCurrentlyDark)
                            
                            VStack(spacing: 12) {
                                TextField("Usuario", text: $username)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(isCurrentlyDark ? Color(white: 0.15) : Color.white)
                                    .cornerRadius(12)
                                    .textInputAutocapitalization(.never)
                                
                                SecureField("Contraseña", text: $password)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(isCurrentlyDark ? Color(white: 0.15) : Color.white)
                                    .cornerRadius(12)
                            }
                            .animation(.easeInOut(duration: 0.6), value: isCurrentlyDark)
                            
                            if !errorMensaje.isEmpty {
                                Text(errorMensaje)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .transition(.opacity)
                            }
                            
                            Button(action: { Task { await conectarFilebrowser() } }) {
                                HStack {
                                    if isLoadingLogin {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Conectar al Servidor")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.4), radius: 5, x: 0, y: 3)
                            }
                            .disabled(isLoadingLogin)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }
            }
        }
        .preferredColorScheme(isAutoTheme ? nil : (isDarkMode ? .dark : .light))
    }
}

// MARK: - Vista de Archivos (DOBLE PANEL IN-PLACE)
struct NubeView: View {
    var token: String
    @State private var localPath: String
    var baseURL: String
    var isDark: Bool
    var alCerrarSesion: () -> Void
    
    init(token: String, initialPath: String, baseURL: String, isDark: Bool, alCerrarSesion: @escaping () -> Void) {
        self.token = token
        _localPath = State(initialValue: initialPath)
        self.baseURL = baseURL
        self.isDark = isDark
        self.alCerrarSesion = alCerrarSesion
    }
    
    @State private var archivos: [FBItem] = []
    @State private var estaCargando = true
    @State private var mostrarSelectorArchivos = false
    
    @State private var modoSeleccionActive = false
    @State private var itemsSeleccionados = Set<String>()
    
    @State private var estadoOperacion: String = ""
    @State private var isProcessing = false
    
    @State private var mostrarAlertaCarpeta = false
    @State private var nombreNuevaCarpeta = ""
    
    @State private var mostrarExportador = false
    @State private var documentoAExportar: DownloadedFile?
    @State private var nombreDescargaSugerido = "Descarga"
    
    @AppStorage("agruparPorTipo") private var agruparPorTipo = false
    let columnasGrid = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 16)]
    
    var carpetas: [FBItem] { archivos.filter { $0.isDir } }
    var documentos: [FBItem] { archivos.filter { !$0.isDir } }
    
    // Nombre formateado para el título superior
    var currentTitle: String {
        localPath == "/" ? "Home" : URL(fileURLWithPath: localPath).lastPathComponent
    }
    
    func navegarACarpeta(path: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.archivos = []
            self.estaCargando = true
            self.localPath = path
            self.itemsSeleccionados.removeAll()
        }
        Task { await cargarArchivos() }
    }
    
    func retrocederCarpeta() {
        var newPath = URL(fileURLWithPath: localPath).deletingLastPathComponent().path
        if newPath.isEmpty || newPath == "." { newPath = "/" }
        if !newPath.hasSuffix("/") { newPath += "/" }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            self.archivos = []
            self.estaCargando = true
            self.localPath = newPath
            self.itemsSeleccionados.removeAll()
        }
        Task { await cargarArchivos() }
    }
    
    func cargarArchivos() async {
        let rutaSegura = localPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? localPath
        guard let url = URL(string: "\(baseURL)/api/resources\(rutaSegura)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let respuesta = try JSONDecoder().decode(FilebrowserResponse.self, from: data)
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.archivos = respuesta.items ?? []
                        self.archivos.sort { $0.name.lowercased() < $1.name.lowercased() }
                        self.estaCargando = false
                    }
                }
            }
        } catch {
            await MainActor.run { self.estaCargando = false }
        }
    }
    
    func crearCarpeta() async {
        guard !nombreNuevaCarpeta.isEmpty else { return }
        await MainActor.run { self.isProcessing = true; self.estadoOperacion = "Creando carpeta..." }
        
        var rutaDestino = localPath
        if !rutaDestino.hasSuffix("/") { rutaDestino += "/" }
        rutaDestino += "\(nombreNuevaCarpeta)/"
        
        let rutaSegura = rutaDestino.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/api/resources\(rutaSegura)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        try? await URLSession.shared.data(for: request)
        
        await MainActor.run {
            self.nombreNuevaCarpeta = ""
            self.isProcessing = false
        }
        await cargarArchivos()
    }
    
    func subirArchivos(urlsLocales: [URL]) async {
        await MainActor.run { self.isProcessing = true; self.estadoOperacion = "Preparando subida..." }
        for (index, urlLocal) in urlsLocales.enumerated() {
            guard urlLocal.startAccessingSecurityScopedResource() else { continue }
            await MainActor.run { self.estadoOperacion = "Subiendo \(index + 1) de \(urlsLocales.count)..." }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(urlLocal.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            do {
                try FileManager.default.copyItem(at: urlLocal, to: tempURL)
                let nombreArchivo = tempURL.lastPathComponent
                var rutaBase = localPath
                if !rutaBase.hasSuffix("/") { rutaBase += "/" }
                let rutaDestino = "\(rutaBase)\(nombreArchivo)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                guard let url = URL(string: "\(baseURL)/api/resources\(rutaDestino)") else { continue }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(token, forHTTPHeaderField: "X-Auth")
                let (_, _) = try await URLSession.shared.upload(for: request, fromFile: tempURL)
                try? FileManager.default.removeItem(at: tempURL)
            } catch {}
            urlLocal.stopAccessingSecurityScopedResource()
        }
        await MainActor.run { self.isProcessing = false; self.estadoOperacion = "" }
        await cargarArchivos()
    }
    
    func descargarSeleccion() async {
        await MainActor.run { self.isProcessing = true; self.estadoOperacion = "Preparando descarga..." }
        let fileManager = FileManager.default
        var urlDescarga: URL?
        var sugerenciaNombre = "Descarga"
        
        if itemsSeleccionados.count == 1 {
            let path = itemsSeleccionados.first!
            let item = archivos.first(where: { $0.path == path })
            let rutaSegura = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            if item?.isDir == true {
                urlDescarga = URL(string: "\(baseURL)/api/raw\(rutaSegura)?algo=zip")
                sugerenciaNombre = "\(item?.name ?? "Carpeta").zip"
            } else {
                urlDescarga = URL(string: "\(baseURL)/api/raw\(rutaSegura)")
                sugerenciaNombre = item?.name ?? "Archivo"
            }
        } else {
            let pathsConcatenados = itemsSeleccionados.joined(separator: ",")
            let querySegura = pathsConcatenados.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlDescarga = URL(string: "\(baseURL)/api/raw/?files=\(querySegura)&algo=zip")
            sugerenciaNombre = "Seleccion_Multiple.zip"
        }
        guard let finalURL = urlDescarga else { await MainActor.run { self.isProcessing = false }; return }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        
        do {
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(sugerenciaNombre)
                if fileManager.fileExists(atPath: destinationURL.path) { try? fileManager.removeItem(at: destinationURL) }
                try fileManager.moveItem(at: tempURL, to: destinationURL)
                
                await MainActor.run {
                    self.documentoAExportar = DownloadedFile(fileURL: destinationURL)
                    self.nombreDescargaSugerido = sugerenciaNombre
                    self.isProcessing = false
                    self.mostrarExportador = true
                    self.modoSeleccionActive = false
                    self.itemsSeleccionados.removeAll()
                }
            } else { await MainActor.run { self.isProcessing = false } }
        } catch { await MainActor.run { self.isProcessing = false } }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isWideScreen = geometry.size.width > 600
            
            ZStack {
                (isDark ? Color(white: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.98))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: isDark)
                
                if isWideScreen {
                    // MODO DOBLE PANEL (iPad / Pantallas Grandes)
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            if localPath != "/" {
                                Button(action: retrocederCarpeta) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("Volver")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .padding()
                                }
                                Divider()
                            }
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(localPath == "/" ? "Carpetas Principales" : "Subcarpetas")
                                        .font(.title3.bold())
                                        .foregroundColor(isDark ? .white : .black)
                                        .padding(.horizontal)
                                        .padding(.top, 15)
                                    
                                    if estaCargando {
                                        ProgressView().padding()
                                    } else if carpetas.isEmpty {
                                        Text("No hay subcarpetas.")
                                            .foregroundColor(.gray)
                                            .padding()
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    } else {
                                        ForEach(carpetas) { carpeta in
                                            FolderRowView(
                                                folder: carpeta,
                                                isSelected: itemsSeleccionados.contains(carpeta.path),
                                                isSelectionMode: modoSeleccionActive,
                                                isDark: isDark
                                            ) {
                                                if modoSeleccionActive {
                                                    toggleSeleccion(path: carpeta.path)
                                                } else {
                                                    navegarACarpeta(path: carpeta.path)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .frame(width: geometry.size.width * 0.26)
                        .background(isDark ? Color(white: 0.12) : Color.white)
                        .animation(.easeInOut(duration: 0.6), value: isDark)
                        
                        Divider().background(isDark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Picker("Vista", selection: $agruparPorTipo) {
                                Text("General").tag(false)
                                Text("Por Tipo").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    if estaCargando {
                                        HStack { Spacer(); ProgressView().scaleEffect(1.2); Spacer() }.padding(.top, 50)
                                    } else if documentos.isEmpty {
                                        HStack { Spacer(); Text("No hay archivos sueltos aquí.").foregroundColor(.gray); Spacer() }.padding(.top, 50)
                                    } else {
                                        if agruparPorTipo {
                                            let grouped = Dictionary(grouping: documentos, by: { ($0.name as NSString).pathExtension.lowercased() })
                                            ForEach(grouped.keys.sorted(), id: \.self) { key in
                                                VStack(alignment: .leading) {
                                                    Text(key.isEmpty ? "Otros" : key.uppercased())
                                                        .font(.title3.bold())
                                                        .foregroundColor(isDark ? .white : .black)
                                                        .padding(.horizontal)
                                                    
                                                    LazyVGrid(columns: columnasGrid, spacing: 16) {
                                                        ForEach(grouped[key]!) { doc in
                                                            ItemCardView(archivo: doc, isSelected: itemsSeleccionados.contains(doc.path), isSelectionMode: modoSeleccionActive, baseURL: baseURL, token: token, isDark: isDark)
                                                                .onTapGesture { manejarToqueArchivo(doc.path) }
                                                        }
                                                    }
                                                    .padding(.horizontal)
                                                }
                                            }
                                        } else {
                                            LazyVGrid(columns: columnasGrid, spacing: 16) {
                                                ForEach(documentos) { doc in
                                                    ItemCardView(archivo: doc, isSelected: itemsSeleccionados.contains(doc.path), isSelectionMode: modoSeleccionActive, baseURL: baseURL, token: token, isDark: isDark)
                                                        .onTapGesture { manejarToqueArchivo(doc.path) }
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                    Spacer().frame(height: 80)
                                }
                            }
                        }
                        .frame(width: geometry.size.width * 0.74)
                    }
                } else {
                    // MODO MÓVIL (Todo apilado)
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Fijo para Móvil (Botón Volver + Título)
                        if localPath != "/" {
                            VStack(alignment: .leading, spacing: 5) {
                                Button(action: retrocederCarpeta) {
                                    HStack { Image(systemName: "chevron.left"); Text("Volver") }
                                        .font(.headline).foregroundColor(.red)
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                                
                                Text(currentTitle)
                                    .font(.title.bold())
                                    .foregroundColor(isDark ? .white : .black)
                                    .padding(.horizontal)
                                    .padding(.bottom, 10)
                            }
                            .background((isDark ? Color(white: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.98)).ignoresSafeArea(edges: .top))
                        }
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Vista vacía global
                                if !estaCargando && archivos.isEmpty {
                                    VStack(spacing: 15) {
                                        Spacer().frame(height: 50)
                                        Image(systemName: "folder.badge.plus")
                                            .font(.system(size: 70))
                                            .foregroundColor(.blue.opacity(0.6))
                                        Text("Esta carpeta está vacía")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                        Text("Puedes subir archivos o crear una carpeta en el botón '+'.")
                                            .font(.subheadline)
                                            .foregroundColor(.gray.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    if !documentos.isEmpty || !carpetas.isEmpty {
                                        Picker("Vista", selection: $agruparPorTipo) {
                                            Text("General").tag(false)
                                            Text("Por Tipo").tag(true)
                                        }
                                        .pickerStyle(.segmented)
                                        .padding(.horizontal)
                                        .padding(.top, localPath == "/" ? 15 : 0)
                                    }
                                    
                                    if !carpetas.isEmpty {
                                        VStack(alignment: .leading) {
                                            Text("Carpetas")
                                                .font(.title3.bold())
                                                .foregroundColor(isDark ? .white : .black)
                                                .padding(.horizontal)
                                            
                                            LazyVGrid(columns: columnasGrid, spacing: 16) {
                                                ForEach(carpetas) { carpeta in
                                                    ItemCardView(archivo: carpeta, isSelected: itemsSeleccionados.contains(carpeta.path), isSelectionMode: modoSeleccionActive, baseURL: baseURL, token: token, isDark: isDark)
                                                        .onTapGesture {
                                                            if modoSeleccionActive { toggleSeleccion(path: carpeta.path) }
                                                            else { navegarACarpeta(path: carpeta.path) }
                                                        }
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                    
                                    if !documentos.isEmpty {
                                        if agruparPorTipo {
                                            let grouped = Dictionary(grouping: documentos, by: { ($0.name as NSString).pathExtension.lowercased() })
                                            ForEach(grouped.keys.sorted(), id: \.self) { key in
                                                VStack(alignment: .leading) {
                                                    Text(key.isEmpty ? "Otros" : key.uppercased())
                                                        .font(.title3.bold())
                                                        .foregroundColor(isDark ? .white : .black)
                                                        .padding(.horizontal)
                                                    
                                                    LazyVGrid(columns: columnasGrid, spacing: 16) {
                                                        ForEach(grouped[key]!) { doc in
                                                            ItemCardView(archivo: doc, isSelected: itemsSeleccionados.contains(doc.path), isSelectionMode: modoSeleccionActive, baseURL: baseURL, token: token, isDark: isDark)
                                                                .onTapGesture { manejarToqueArchivo(doc.path) }
                                                        }
                                                    }.padding(.horizontal)
                                                }
                                            }
                                        } else {
                                            LazyVGrid(columns: columnasGrid, spacing: 16) {
                                                ForEach(documentos) { doc in
                                                    ItemCardView(archivo: doc, isSelected: itemsSeleccionados.contains(doc.path), isSelectionMode: modoSeleccionActive, baseURL: baseURL, token: token, isDark: isDark)
                                                        .onTapGesture { manejarToqueArchivo(doc.path) }
                                                }
                                            }.padding(.horizontal)
                                        }
                                    }
                                }
                                Spacer().frame(height: 80)
                            }
                            .padding(.vertical)
                        }
                    }
                }
                
                // Overlays y descargas...
                if isProcessing {
                    ZStack {
                        Color(UIColor.systemBackground).opacity(0.8).ignoresSafeArea()
                        VStack(spacing: 20) {
                            ProgressView().scaleEffect(1.5).tint(.blue)
                            Text(estadoOperacion).font(.headline).foregroundColor(.primary)
                        }
                        .padding(40).background(isDark ? Color(white: 0.15) : Color.white).cornerRadius(20).shadow(color: .black.opacity(0.2), radius: 20)
                    }
                    .transition(.opacity)
                }
                
                if modoSeleccionActive && !itemsSeleccionados.isEmpty {
                    VStack {
                        Spacer()
                        Button(action: { Task { await descargarSeleccion() } }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Descargar (\(itemsSeleccionados.count))")
                            }
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                            .background(Color.blue).cornerRadius(16).padding(.horizontal, 25).padding(.bottom, 20)
                            .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // En móvil, si no estamos en home, ocultamos el navigationTitle nativo porque usamos el custom
            .navigationTitle(localPath == "/" ? "Home" : (isWideScreen ? currentTitle : ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !modoSeleccionActive {
                        Button(action: alCerrarSesion) { Image(systemName: "rectangle.portrait.and.arrow.right").foregroundColor(.red) }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !archivos.isEmpty {
                        Button(action: {
                            withAnimation { modoSeleccionActive.toggle(); itemsSeleccionados.removeAll() }
                        }) { Text(modoSeleccionActive ? "Cancelar" : "Seleccionar").fontWeight(.medium) }
                    }
                    if !modoSeleccionActive {
                        Menu {
                            Button(action: { mostrarSelectorArchivos = true }) { Label("Subir Archivo", systemImage: "doc.badge.plus") }
                            Button(action: { mostrarAlertaCarpeta = true }) { Label("Nueva Carpeta", systemImage: "folder.badge.plus") }
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                    }
                }
            }
            .alert("Nueva Carpeta", isPresented: $mostrarAlertaCarpeta) {
                TextField("Nombre de la carpeta", text: $nombreNuevaCarpeta)
                Button("Cancelar", role: .cancel) { nombreNuevaCarpeta = "" }
                Button("Crear") { Task { await crearCarpeta() } }
            }
            .fileImporter(isPresented: $mostrarSelectorArchivos, allowedContentTypes: [.data], allowsMultipleSelection: true) { resultado in
                switch resultado {
                case .success(let urls): Task { await subirArchivos(urlsLocales: urls) }
                case .failure(let error): print("Error: \(error)")
                }
            }
            .fileExporter(isPresented: $mostrarExportador, document: documentoAExportar, contentType: .data, defaultFilename: nombreDescargaSugerido) { _ in
                documentoAExportar = nil
            }
            .task { await cargarArchivos() }
        }
    }
    
    private func manejarToqueArchivo(_ path: String) {
        if modoSeleccionActive {
            toggleSeleccion(path: path)
        } else {
            itemsSeleccionados.insert(path)
            Task { await descargarSeleccion() }
        }
    }
    
    private func toggleSeleccion(path: String) {
        withAnimation(.easeInOut(duration: 0.1)) {
            if itemsSeleccionados.contains(path) { itemsSeleccionados.remove(path) }
            else { itemsSeleccionados.insert(path) }
        }
    }
}

// MARK: - Diseño de Carpeta para el Panel Izquierdo
struct FolderRowView: View {
    var folder: FBItem
    var isSelected: Bool
    var isSelectionMode: Bool
    var isDark: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
                        .font(.title3)
                        .transition(.scale)
                }
                
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text(folder.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(isDark ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.caption)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
            .background(
                isSelected
                    ? Color.blue.opacity(isDark ? 0.2 : 0.1)
                    : (isDark ? Color(white: 0.16) : Color(white: 0.96))
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tarjeta de Archivo Individual (Grid Cell)
struct ItemCardView: View {
    var archivo: FBItem
    var isSelected: Bool
    var isSelectionMode: Bool
    var baseURL: String
    var token: String
    var isDark: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                if archivo.hasPreview {
                    AuthImageView(path: archivo.path, baseURL: baseURL, token: token, fallbackIcon: archivo.iconName, fallbackColor: archivo.iconColor)
                } else {
                    Image(systemName: archivo.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 45)
                        .foregroundColor(archivo.iconColor)
                        .frame(maxWidth: .infinity)
                }
                
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .blue : .gray.opacity(0.4))
                        .background(Circle().fill(isDark ? Color(white: 0.15) : .white).padding(2))
                        .offset(x: 10, y: -10)
                }
            }
            .padding(.top, 8)
            .frame(height: 70)
            
            VStack(spacing: 4) {
                Text(archivo.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isDark ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if !archivo.isDir, let size = archivo.size {
                    Text(formatBytes(size))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            (isDark ? Color(white: 0.14) : Color.white)
                .animation(.easeInOut(duration: 0.6), value: isDark)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.03), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 2)
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Image Loader
struct AuthImageView: View {
    let path: String
    let baseURL: String
    let token: String
    let fallbackIcon: String
    let fallbackColor: Color
    
    @State private var image: UIImage?
    @State private var failed = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 55)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 3)
            } else if failed {
                Image(systemName: fallbackIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 45)
                    .foregroundColor(fallbackColor)
            } else {
                ProgressView().frame(height: 45)
            }
        }
        .frame(maxWidth: .infinity)
        .task { await loadPreview() }
    }
    
    func loadPreview() async {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let url = URL(string: "\(baseURL)/api/preview/thumb\(encodedPath)") else { failed = true; return }
        
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-Auth")
        request.cachePolicy = .returnCacheDataElseLoad
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let uiImage = UIImage(data: data) {
                await MainActor.run { self.image = uiImage }
            } else {
                await MainActor.run { self.failed = true }
            }
        } catch {
            await MainActor.run { self.failed = true }
        }
    }
}

// MARK: - Extensiones para Íconos
extension FBItem {
    var hasPreview: Bool {
        if isDir { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "heic", "webp", "mp4", "mov", "avi", "mkv", "pdf"].contains(ext)
    }
    
    var iconName: String {
        if isDir { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "video.fill"
        case "mp3", "wav", "m4a", "flac": return "music.note"
        case "pdf": return "doc.viewfinder.fill"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "txt", "md", "csv", "json": return "doc.text.fill"
        case "swift", "py", "js", "html", "css", "cpp": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }
    
    var iconColor: Color {
        if isDir { return .blue }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .purple
        case "mp4", "mov", "avi", "mkv": return .red
        case "mp3", "wav", "m4a", "flac": return .orange
        case "pdf": return .red
        case "zip", "rar", "7z", "tar", "gz": return .yellow
        case "txt", "md", "csv", "json": return .green
        case "swift", "py", "js", "html", "css", "cpp": return .teal
        default: return .gray
        }
    }
}

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
