{-# LANGUAGE ForeignFunctionInterface #-}

module RosInterface where

import System.Environment (getArgs, getProgName)
import Data.List (intercalate)
import Foreign.C
import Foreign.Ptr
import Foreign.Storable
import Foreign.Marshal.Alloc
import qualified Data.ByteString as B
import Data.Serialize
-- import Foreign.Marshal.Array

import Landmark

{#pointer *keypoint_t as KeypointPtr#}

--instance Serialize Keypoint where
--	put (Keypoint x y w bs) = put (x,y,w,bs)
--	get = do (x,y,w,bs) <- get; return (Keypoint x y w bs)


get_px, get_py, get_response :: KeypointPtr -> IO Double
get_px t = {#get keypoint_t->px#} t >>= return . realToFrac
get_py t = {#get keypoint_t->py#} t >>= return . realToFrac
get_response t = {#get keypoint_t->response#} t >>= return . realToFrac

get_descriptor_size, get_feature_id :: KeypointPtr -> IO Int
get_descriptor_size t = {#get keypoint_t->descriptor_size#} t >>= return . fromIntegral
get_feature_id t = {#get keypoint_t->id#} t >>= return . fromIntegral

get_descriptor :: Int -> KeypointPtr -> IO B.ByteString
get_descriptor n t = {#get keypoint_t->descriptor#} t >>= (\cchar -> B.packCStringLen (cchar, n))

keypointById :: Int -> KeypointPtr -> KeypointPtr
keypointById i k = plusPtr k ({# sizeof keypoint_t #} * i)

getKeypoints :: IO [Feature]
getKeypoints = do
	(kps_ptr, num) <- extractKeypoints
	
	sequence [getKeypoints' i kps_ptr | i <- [0..num-1]] where
		getKeypoints' i kps_ptr = do
			let kp = keypointById i kps_ptr
			px <- get_px kp
			py <- get_py kp
			response <- get_response kp
			descriptor_size <- get_descriptor_size kp
			descriptor <- get_descriptor descriptor_size kp
			f_id <- get_feature_id kp
			return $ Feature (FID f_id) Nothing (px, py) response descriptor
			
launchRos :: IO ()
launchRos = do
	args <- getArgs
	prog <- getProgName
	_ <- mainC (intercalate ";" (prog:args))
	return ()

peekInt ptr = fmap fromIntegral (peek ptr)

{#fun extract_keypoints as ^
 {alloca- `Int' peekInt*} -> `KeypointPtr' id#}
 
{#fun unsafe main_c as ^
	{ `String' } -> `Int'#}
