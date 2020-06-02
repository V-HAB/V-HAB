% Bin_diff_coeff: Calculates the Diffusion Coefficient for a binary gas mixture
% Calculation according to VDI-Waermeatlas, p. 170f, D1, 10.1, (115)
function [D_12] = Bin_diff_coeff(Vapor, Inertgas, temp_Gas, pressure_Gas)

	pressure_Gas_bar = pressure_Gas/(10^5);					% Conversion: Pa to Bar

	switch Vapor
		case 'H2O'
			molMass_V = 18.01528;							% [g/mol]
			diffVolume_V = 13.1;							% [-]
		case 'Isopropanol'
			molMass_V = 60.1;								% [g/mol]
			diffVolume_V = 3 * 15.9 + 8 * 2.31 + 6.11;		% [-]

			% C H3 C H O H C H3
			% C3 H8 O

		otherwise
			fprintf('fx: Diff_Coeff: Use Air as Gas_1.\n');
			return
	end

	switch Inertgas
		case 'Air'
			molMass_I = 28.949;				% [g/mol]
			diffVolume_I = 19.7;			% [-]
		case 'N2'
			molMass_I = 28;					% [g/mol]
			diffVolume_I = 18.5;			% [-]
		otherwise
			fprintf('fx: Diff_Coefff: Use H2O as Gas_2.\n');
			return
	end

	D_12_cm2_s = (0.00143 * temp_Gas^1.75 * sqrt(molMass_V^-1 + molMass_I^-1)) / ...
				 (pressure_Gas_bar * sqrt(2) * (diffVolume_V^(1/3) + diffVolume_I^(1/3))^2);

	D_12 = D_12_cm2_s/10000;				% Conversion: cm^2/s to m/s^2
end