%% ReynoldsNumberFilm: Calculates the Reynoldsnumber of the Film as a function of the Condensate Mass Flow.
function [Re_Film] = ReynoldsNumberFilm(MassFlowRate_Film, dynViscosity_Film, CharactLength, CHX_Type)
	switch CHX_Type
		case {'VerticalTube', 'HorizontalTube'}
			Re_Film = (MassFlowRate_Film)/(pi * CharactLength * dynViscosity_Film);
		otherwise
			fprintf('Re_Film: Only VerticalTube implemented yet\n')
				return
	end
end