

module Simulate (landmarks, measurement, camTransition) where

import Data.Maybe (catMaybes)
import Numeric.LinearAlgebra
import Data.Random (RVar)
import Data.Random.Distribution.Normal
import Feature
import Linear
import InternalMath

-- | Create a map, consisting of some predefined landmarks.
landmarks :: [V3 Double]
landmarks = [V3 5 0 0, V3 0 0 5, V3 3 (-1) 3, V3 5 5 5, V3 (-3) (-1.5) (-2), V3 (-3000) (-3000) 3000]

measurePoint :: Camera -> V3 Double -> Maybe Measurement
measurePoint (Camera cp cr) (V3 x y z) = Just m where
	m = vec2euler $ trans cr <> ((3|> [x,y,z]) - cp)

-- | Measure the given landmarks, with an infinite precision.
measurement' :: Camera -> [V3 Double] -> [Measurement]
measurement' cam = catMaybes . map (measurePoint cam)

-- | Measure the landmarks, defined in this file, with a finite precission (additive gaussian noise).
measurement :: Camera -> IO [Measurement]
measurement cam = return $ measurement' cam (filter (\l -> distSq l cam >= 0) landmarks) where
	distSq (V3 x1 y1 z1) (Camera c _) = (x1-c@>0)^^2 + (y1-c@>1)^^2 + (z1-c@>2)^^2


-- | The first camera argument is the 'true' camera position, that the oracle
-- told us. The cameras are the lists of positions in time (t:t-1:t-2:...).
-- The 'true' camera input is one step more advanced (one item longer list),
-- than the second argument.
camTransition :: [Camera] -> [Camera] -> RVar Camera
camTransition [] c = undefined
camTransition (c1:[]) [] = return c1 where
	canonicalCam = Camera (3|>repeat 0) (ident 3)
camTransition (Camera cp2 cr2:Camera cp1 cr1:_) ((Camera cp cr):_) = do
	[xdev,zdev,wdev] <- sequence . take 3 $ repeat stdNormal
	let posdev = 3|> [xdev*0.1,0,zdev*0.1]
	let thetadev = wdev * 0.1
	return $ Camera (cp + movement + posdev) (cr <> rotation <> rotateYmat thetadev) where
		(movement, rotation) = (cp2 - cp1, cr2 <> trans cr1)


