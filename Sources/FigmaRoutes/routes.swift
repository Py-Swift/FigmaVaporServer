import Vapor
import VaporKivyReloader

public func routes(_ app: Application) throws {
    app.get { _ async in "FigmaVaporServer running." }
    try app.register(collection: SetupRoutes())
    try app.register(collection: KvRoutes())
    try app.register(collection: CanvasRoutes())
    try app.register(collection: CanvasPreviewRoutes())
    try app.register(collection: DevicePreviewRoutes())
    try app.register(collection: LabRoutes())
    try app.register(collection: FontRoutes())
    try app.register(collection: ImageRoutes())
    try app.register(collection: WebSocketRoutes())
}
