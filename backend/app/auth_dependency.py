#this file holds the validation dependency for the jwt token on each request-- checks if the token is valid and has not been changed since creation
from uuid import UUID

from app.config import settings #this is to read the needed env variables 
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer #needed to get the authorization header from the request-- it holds the token
import jwt
from jwt import PyJWKClient
from fastapi import Depends, status, HTTPException

jwk_client = PyJWKClient(uri=f"{settings.supabase_url}/auth/v1/.well-known/jwks.json") #gets list of the JWK's from the supabase http cycle-- we need key to go with the token so we can perform the hash check on the token
bearer_split = HTTPBearer() #splits the auth header
#this is the dependency that will be passed into our endpoints for jwt auth-- returns the user id from the jwt payload if it's valid else raises error
#the credentials parameter is an object holding the Authentication header from the response 
def get_curr_user(credentials: HTTPAuthorizationCredentials = Depends(bearer_split)):
    token = credentials.credentials
    try:
        public_key = jwk_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(token, public_key, algorithms=["ES256", "RS256"], audience="authenticated", issuer=f"{settings.supabase_url}/auth/v1")
    except jwt.ExpiredSignatureError:
        #token was expired so it is not valid anymore
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="JWT token is expired")
    except jwt.PyJWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token is not valid")
    #if valid token return the sub(subject) value from payload obj which corresponds to the user id in our case
    #returns as UUID because that is the type of the db user_id
    return UUID(payload['sub'])

