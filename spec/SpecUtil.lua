local Util = {}

function Util.secondsToUnit(x: number): (number, string)
	if x < 0.000001 then
		return x * 1e+9, "ns"
	elseif x >= 0.000001 and x < 0.001 then
		return x * 1e+6, "μs"
	elseif x >= 0.001 and x < 1 and x ~= 0 then
		return x * 1000, "ms"
	elseif x >= 0 and x < 60 then
		return x, "s"
	elseif x >= 60 and x < 3600 then
		return x / 60, "m"
	elseif x >= 3600 and x < 86400 then
		return x / 3600, "h"
	elseif x >= 86400 then
		return x / 86400, "d"
	else
		error("No matching unit found!")
	end
end

function Util.formatTime(seconds: number)
	local num, unit = Util.secondsToUnit(seconds)
	return string.format("%d%s", num, unit)
end

return Util