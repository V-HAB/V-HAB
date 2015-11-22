classdef GenericFilterTable < handle
    % This is a helper class that allows the generic filter model to be
    % used for a wide range of materials that are common in ad-/absorption 
    % processes.
    % Outsourcing the material/process specific values gives an easy way to
    % build up a library of different filter models while at the same time
    % an optimized numerical solver is provided for all models.
    
    % Other properties that have to be adjusted:
    % - Geometry: this has to be done in the filter itself by adding to the switch case 
    
    
    properties
        
        % Set necessary properties for the solver
        fRhoSorbent = 0;            % density of the ad-/absorbing material
        ...
        
        % Could do something similar to the FBA table
        
        % For MODULATION and VALIDATION:
        % Enter manual values for the constants or leave nan to
        % calculate the values according to theoretical assumptions
        k_l = nan;      % kinetic constant [1/s]
        ...
        
        
    end
    
    
    methods
        
        % Necessary functions for the solver
        function this = GenericFilterTable()
            % Construction call
            % constants, properties, etc. can be set here or it can beised
            % to transfer values
            
        end
        
        function [D_L] = get_AxialDispersion_D_L(varargin)
            % Dispersion coefficient
            D_L = 2.90e-3;          % [m^2/s]
        end
        
        %% Using the Linear Driving Force LDF model
        % Calculate/set the kinetic constant
        function [k_l] = get_KineticConst_k_l(input)
            % Check if values were set manually
            if isnan(this.k_l) == 0
                % Initialize
                k_l = zeros(size(input));
                % Assign values
                for i = 1:length(this.k_l)
                    k_l(i,:) = this.k_l(i);
                end
                
            % Or calculate according to assumptions 
            else
                % initialize
                k_l = zeros(size(input));
                % calculate values
                ...
            end
            ...
        end
        
        % Linear(ized) isotherm constant
        function [K] = get_ThermodynConst_K(input)
            % Either define a linear value manually
            if isnan(this.K) == 0
                K = zeros(size(input));
                for iVari = 1:length (this.K)
                    K(iVari, :) = this.K(iVari);
                end
                return;
            end
            
            % Or calculate a loacally linearized constant
            K = this.calculate_q_equ(input) ./ afC_in; 
            K(isnan(K)|K<0) = 0;
        end
    
        % Calculate the equilibrium values of the sorption reaction
        function [q_equ] = calculate_q_equ(~)     
            q_equ = 0;
        end
        
        % Calculate the pressure drop across the bed
        function [fDeltaP] = calculate_dp(~)
            fDeltaP = 0;
        end
        
        
        %% OR
        % Define completely different functions that return a result for
        % the concentration and/or the loading of the substances.
        % EXAMPLE: MetOx Absorption
        % BUT: Need to change the calls in the p2p sorption processor
        
        
    end
end