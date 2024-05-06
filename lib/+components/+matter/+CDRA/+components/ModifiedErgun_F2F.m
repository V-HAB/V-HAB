classdef ModifiedErgun_F2F < matter.procs.f2f
    
    properties (SetAccess = protected, GetAccess = public)
        
        %fFrictionFactor   = 0;
        
        fCellLength = 0; % [m]
        fCrossSection = 0; % [m^2]  Is this correct as already defined w/ values in CDRA
        %fCellDiameter = 0; % [m]
        rVoidFraction = 0; % Is this correct as already defined w/ values in CDRA
        fSphericity = 0;
        fAdsorbentParticleDiameter = 0; % [m], the effective particle diameter for sorbent beads or pellets
        
        fWallFrictionFactor = 0;
        fSuperficialVelocity = 0;
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        % What is the best way to pass or calculate the following as appropriate? 
            % fCellLength (m)
            % fVoidFraction
            % CCAA air fViscosity (Pa*s) and fDensity (kg/m^3)
            % fSuperficialVelocity (m/s)
            % fSphericity
            % fAdsorbentParticleDiameter (m)
            % fWallFrictionFactor
        function this = ModifiedErgun_F2F(oContainer, sName, tInput)

            this@matter.procs.f2f(oContainer, sName);

            csInputFields = fieldnames(tInput);
            csPossibleFieldNames = {'fCellLength', 'fCrossSection', 'rVoidFraction', 'fSphericity', 'fAdsorbentParticleDiameter'};
            
            if length(csInputFields) ~= length(csPossibleFieldNames)
                error('insufficient inputs provided to ModifiedErgun_F2F, check the required inputs for the tInput struct');
            end
            
            for iField = 1:length(csInputFields)
                sField = csInputFields{iField};
                if ~any(strcmp(sField, csPossibleFieldNames))
                    error('VHAB:Phase:UnknownTimeStepProperty', ['The function setTimeStepProperties was provided the unknown input parameter: ', sField, ' please view the help of the function for possible input parameters.']);
                end

                this.(sField) = tInput.(sField);
            end
            %this.fFrictionFactor   = fFrictionFactor;
            %this.fCellLength = fCellLength;  % e.g. = this.tGeometry.Zeolite5A.fLength/this.tGeometry.Zeolite5A.iCellNumber
            %this.fCrossSection = fCrossSection; % e.g. = this.tGeometry.Zeolite5A.fCrossSection
            %this.fCellDiameter = fCellDiameter; % e.g. = sqrt(this.tGeometry.Zeolite5A.fCrossSection*4/PI)
            %this.rVoidFraction = rVoidFraction; % e.g. this.tGeometry.Zeolite13x.rVoidFraction 
            %this.fSuperficialVelocity = fSuperficialVelocity; % use fFlowRate or this.tGeometry.Zeolite13x.fVolumeFlow and this.tGeometry.Zeolite5A.fCrossSection?
            %this.fSphericity = fSphericity; % Note, adsorbent particles have been assumed to be spherical.  The average diameters are currently hardwired. See CDRA.m Lines 300-315.
            %this.fAdsorbentParticleDiameter = fAdsorbentParticleDiameter; % Adsorbent particle diameters are currently hardwired. See CDRA.m Lines 300-315.
            
            % Get dynamic viscosity and density from V-HAB directly
            %this.fViscosity = fAirViscosity;
            %this.fDensity = fAirDensity;
            
            this.fWallFrictionFactor =  1+(4*this.fAdsorbentParticleDiameter)/(6*sqrt(this.fCrossSection)*(1-this.rVoidFraction));
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            % ∆p/L_b =150∙(1-ε)^2/ε^3 ∙(μ * u_0)/(φ_s * D_p )^2 ∙F^2+1.75∙(1-ε)/ε^3 ∙(ρ * u_0^2)/(φ_s * D_p )∙F
                % Gas density ρ 
                % Geometric dimensions (L_b, D_b) and void fraction ε for each sorbent bed.  
                % Effective adsorbent particle diameter D_p
                % superficial velocity u_0
                % Sphericity φ_s=(6 ⁄ D_p )/(S_p / V_p )
                % Wall friction correction factor F=1+(4*D_p)/(6*D_b * (1-ε) )
                
                
            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);
            oInExme = this.oBranch.getInEXME();
            
            try            
                fDensityIn = oFlowIn.getDensity();
                fDensityOut = oFlowOut.getDensity();
                
                fDensity = (fDensityIn + fDensityOut) / 2;
            catch
                fDensity = oInExme.oPhase.fDensity;
            end

            if fDensity == 0 
                fDensity = this.oBranch.oContainer.toStores.AirInlet.toPhases.AirInlet_Phase_1.fDensity;
            end

            % Flow speed for a circular geometry. Flowrate is current mass
            % flow in kg/s
            this.fSuperficialVelocity = abs(fFlowRate) / (this.fCrossSection * fDensity); % [m/s]
            
            fDynamicViscosity = oFlowIn.getDynamicViscosity(); % [Pa-s]
            if fDynamicViscosity == 0
                fDynamicViscosity = 17.2 / 10^6;
            end
            % this.fDynamicViscosity = fDynamicViscosity; 
            
            fDeltaPressure = this.fCellLength * (150*(1-this.rVoidFraction)^2/this.rVoidFraction^3*(fDynamicViscosity * this.fSuperficialVelocity)/(this.fSphericity * this.fAdsorbentParticleDiameter)^2 * this.fWallFrictionFactor^2 +...
                1.75*(1-this.rVoidFraction)/this.rVoidFraction^3*(fDensity * this.fSuperficialVelocity^2)/(this.fSphericity * this.fAdsorbentParticleDiameter) * this.fWallFrictionFactor); % [Pa]
            %fDeltaPressure = fFlowRate^2 * this.fFrictionFactor;
            this.fDeltaPressure = fDeltaPressure;
        end

    end

end
