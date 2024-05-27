
land = {}
land.SurfaceType = {
  LAND            = 1,
  SHALLOW_WATER   = 2,
  WATER           = 3,
  ROAD            = 4,
  RUNWAY          = 5,
  }


function land.getHeight(point) 
  return 0
end

function land.getSurfaceHeightWithSeabed(point) 
  return 0
end

function land.getSurfaceType(point) 
  return land.SurfaceType.WATER
end

function land.isVisible(point1, point2)
  return true
end

function land.getIP(origin, direction, distance) 
  return nil
end

function land.profile(point1, point2) 
  return {}
end

function land.getClosestPointOnRoads(roadType ,xCoord , yCoord)
  
  return 0, 0
end

function land.findPathOnRoads(roadType , xCoord, yCoord , destX, destY ) 
  return {}
end

return land