
class ScanResource:
    MAX_SIZE = 5 * 1024 * 1024 # 5MB

    async def on_post(self, req, resp):
        # Validate request body
        if req.content_length > ScanResource.MAX_SIZE:
            resp.status = falcon.HTTP_413
            return
        body = await req.bounded_stream.readall()

        # TODO: Scan image bytes for amounts and categories
