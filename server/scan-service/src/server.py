import logging
import falcon
import falcon.asgi
from resources.scan_resource import ScanResource
from media_handlers.text_handler import TextHandler

# Add error logging
logging.basicConfig(format="%(asctime)s [%(levelname)s] %(message)s", level=logging.INFO)

# Initialize server with default plain/text content type
cors_middleware = falcon.CORSMiddleware(allow_origins="http://localhost:8081")
app = falcon.asgi.App(media_type=falcon.MEDIA_TEXT, middleware=[cors_middleware])

# Set up media handlers
text_handler = TextHandler()
app.req_options.media_handlers['text/plain'] = text_handler
app.resp_options.media_handlers['text/plain'] = text_handler

# Initialize ML resources
scan_resource = ScanResource()

# Set up routes for each resource
app.add_route("/api/v1/scan", scan_resource)
