function [Re] = ReynoldsNumberGas(MassFlowRate_Gas, dynViscosity_Gas, CharactLength, CHX_Type)
%ReynoldsNumberGas Calculates the Reynolds Number of the Gas Flow (Water Vapor + Air) based on CHX type.
%   Used for the Nusselt-Correlations to calculate the heat transfer coefficient

	switch CHX_Type
		case {'VerticalTube', 'HorizontalTube'}
			Re = (4 * MassFlowRate_Gas)/(pi * CharactLength * dynViscosity_Gas);
		otherwise
			fprintf('Re_Gas: Only VerticalTube implemented yet\n')
				return
	end
end
