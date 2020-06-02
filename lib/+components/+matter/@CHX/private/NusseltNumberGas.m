%% NusseltNumberGas: Calculates the Nusselt-Number of the Gas for the selected CHX type
function [Nu_Gas] = NusseltNumberGas(Reynolds_Gas, Prandtl_Gas, CHX_Type)

	switch CHX_Type
	case {'VerticalTube', 'HorizontalTube'}
		Nu_Gas = 0.0214 * (Reynolds_Gas^0.8 - 100) * Prandtl_Gas^0.4;
	otherwise
		fprintf('Only VerticalTube implemented yet\n')
			return
	end

end