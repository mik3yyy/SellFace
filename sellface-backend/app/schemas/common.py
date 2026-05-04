from pydantic import BaseModel


class MessageOut(BaseModel):
    message: str


class DeviceTokenIn(BaseModel):
    token: str
    platform: str = "ios"
