#this file holds the validation dependency for the jwt token on each request-- checks if the token is valid and has not been changed since creation
from uuid import UUID

from app.config import settings #this is to read the needed env variables 
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer #needed to get the authorization header from the request-- it holds the token
import httpx
import jwt
from jwt import PyJWKClient
from fastapi import Depends, status, HTTPException

supabase_url = settings.supabase_url.rstrip("/")
jwk_client = PyJWKClient(
    uri=f"{supabase_url}/auth/v1/.well-known/jwks.json"
)
bearer_split = HTTPBearer() #splits the auth header
#this is the dependency that will be passed into our endpoints for jwt auth-- returns the user id from the jwt payload if it's valid else raises error
#the credentials parameter is an object holding the Authentication header from the response 
def _get_user_from_supabase(token: str) -> UUID:
    try:
        response = httpx.get(
            f"{supabase_url}/auth/v1/user",
            headers={
                "apikey": settings.supabase_publishable_key,
                "Authorization": f"Bearer {token}",
            },
            timeout=10,
        )
    except httpx.HTTPError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not reach Supabase to validate the token",
        )

    if response.status_code != status.HTTP_200_OK:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is not valid for the configured Supabase project",
        )

    try:
        user_id = response.json()["id"]
        return UUID(user_id)
    except (KeyError, TypeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Supabase returned an invalid user identity",
        )


def get_curr_user(credentials: HTTPAuthorizationCredentials = Depends(bearer_split)):
    token = credentials.credentials
    try:
        signing_key = jwk_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256", "RS256"],
            audience="authenticated",
            issuer=f"{supabase_url}/auth/v1",
        )
    except jwt.ExpiredSignatureError:
        #token was expired so it is not valid anymore
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="JWT token is expired")
    except jwt.PyJWTError:
        return _get_user_from_supabase(token)
    except (ValueError, TypeError):
        return _get_user_from_supabase(token)
    #if valid token return the sub(subject) value from payload obj which corresponds to the user id in our case
    #returns as UUID because that is the type of the db user_id
    try:
        return UUID(payload["sub"])
    except (KeyError, TypeError, ValueError):
        return _get_user_from_supabase(token)
