% SherwoodNumber: Calculates the Schmidt-Number based on CHX type

function [Sh] = SherwoodNumber(Re_Gas, SchmidtNumber_Gas, CHX_Type)
	
	% DebugMode = false;

	switch CHX_Type
		case {'VerticalTube', 'HorizontalTube'}
			% According to VDI Waermeatlas, J2, Bsp. 1
			Sh = 0.0214 * ((Re_Gas^0.8) - 100) * (SchmidtNumber_Gas^0.4);
		otherwise
			fprintf('Only VerticalTube implemented yet\n')
			return

		% TODO: Korrelationen erweitern fuer horizontales Rohr, Kreuzstrom, ...
	end

end
