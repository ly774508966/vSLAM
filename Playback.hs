-- Get the input data from Serialized files.

module Playback where

import Text.Printf (printf)
import qualified Data.ByteString as BS
import Data.Serialize
import Numeric.LinearAlgebra
import Numeric.LinearAlgebra.Util ((&), (!), (#), zeros)

import Landmark
import Camera
import InternalMath

measurement :: Int -> IO (Double, [Feature])
measurement i = do
	bs <- BS.readFile (printf "../data/yard1-3/features_%04d.data" i)
	return $ case decode bs of 
		Left err -> undefined
		Right (dt, val) -> (dt, map (\v -> v { fpos = (\(theta, phi) -> (theta, -phi)) $ fpos v }) val)


-- Take the dt and the last camera position, return the next camera position estimate
camTransition :: Double -> [ExactCamera] -> ExactCamera -> GaussianCamera
camTransition dt cams (ExactCamera ccp ccr) = 
	GaussianCamera (6|> [x',y',z',a',0,0]) ((posCov ! empty33) # (empty33 ! rotCov))
	where 
		camVel = camVelocity cams :: Vector Double
		[x',y',z'] = zipWith (+) (toList ccp) (toList camVel)
		[a',b',g'] = toList $ rotmat2euler ccr
		posCov = ccr <> (diag $ scale dt $ 3|> [0.1, 0.1, 0.3]) <> trans ccr
		rotCov = diag $ scale dt $ 3|> [0.3, 0.03, 0.03]
		empty33 = zeros 3 3

-- | Compute the velocity from the most recent camera estimates.
camVelocity :: [ExactCamera] -> Vector Double
camVelocity [ExactCamera cp1 _, ExactCamera cp2 _] =
	(cp1 - cp2) & (3|> [0..])
camVelocity _ = 6|> repeat 0
