if not math.tofixed then
  function math.tofixed(value)
    return value
  end
end

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

if not math.Quaternion then
  function math.Quaternion(x, y, z)
    return { x = x, y = y, z = z }
  end
end
