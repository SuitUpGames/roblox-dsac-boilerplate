local InstanceHelper = {}

function InstanceHelper.GetChildren(root: Instance)
	local res = {}

	for _, child: string in root:GetChildren() do
		res[child.Name] = child
	end

	return res
end

return InstanceHelper
