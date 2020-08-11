classdef MicrobialCheckValve < matter.procs.f2f
    % This is a checkvalve which only allows fluid to pass in one direction
    % and blocks it if it would flow the other way. This valve currently
    % only works together with the multi branch solver but could be
    % implemented for other solvers (interval iterative) as well. 

    
    properties (SetAccess = protected, GetAccess = public)
        % Current Pressure Drop
        fPressureDrop = 0;
        
        % Coefficient for the pressure drop if fluid is allowed to flow
        % through the valve. Is multiplied with the flowrate^2 to calculate
        % pressure drop
        fFlowThroughPressureDropCoefficient = 0;
        
        % Object reference to the valve that should be opened if the
        % microbial check valve condition is exceeded
        oOtherValve;
        
        bOpen = true;
        
        abContaminants;
        
        afCarbonAtomsInMolecule;
        
        fTOC = 0;
        fPPM = 0;
    end
    
    methods
        function  this = MicrobialCheckValve(oContainer, sName, bInitialOpen, oOtherValve, abContaminants)
            % Input Parameters:
            %   bInitialOpen - decides if the valve is initially open
            %   oOtherValve - reference to the other valve, when the check
            %   valve is open, the other valve must be closed and vice
            %   versa
            
            this@matter.procs.f2f(oContainer, sName);
            
            this.bOpen = bInitialOpen;
            this.oOtherValve = oOtherValve;
            this.abContaminants = abContaminants;
            
            this.afCarbonAtomsInMolecule = zeros(1, this.oMT.iSubstances);
            
            for iSubstance = 1:this.oMT.iSubstances
                sSubstance = this.oMT.csI2N{iSubstance};
                tAtmos = this.oMT.extractAtomicTypes(sSubstance);
                if isfield(tAtmos, 'C')
                    this.afCarbonAtomsInMolecule(iSubstance) = tAtmos.C;
                end
            end
            
            this.supportSolver('callback',  @this.solverDeltas);
        end
        
        
        
        function fPressureDrop = solverDeltas(this, fFlowRate)
            
            % we only calculate the valve in case that the solver has
            % already converged. Otherwise the valve can result in
            % oscillations in iterative solvers like the iterative
            % multibranch, the iterative or the interval solver!
            try 
                if ~this.oBranch.oHandler.bFinalLoop
                    fPressureDrop = this.fPressureDrop;
                    return
                end
            catch
                % if the solver is not iterative always calculate the valve
            end
                
            
            % No flow/reverse flow - open
            if fFlowRate <= 0
                this.fPressureDrop = 0;
                this.bOpen = true;
                
            % if we have a flow through the valve, check the flow for the
            % Total Organic Concentration (TOC) and for the ppm values of
            % other contaminants
            else
                % The TOC Limit for the US Segment is mentioned to be 0.5
                % mg/l while the conductivity is limited to 25 micromhos =
                % 25 microsiemens = 16.0256 ppm according to:
                % "Performance Qualification Test of the ISS Water
                % Processor Assembly (WPA) Expendables", Layne Carter
                % et.al, 2005
                arInFlowMassRatios = this.aoFlows(1).arPartialMass;
                afPPM = this.oMT.calculatePPM(arInFlowMassRatios);
                this.fPPM = sum(afPPM(this.abContaminants));
                % This is the TOC value in kg (Carbon) / totalMass, which
                % is almost identical to kg(Carbon) / l (water) and
                % therefore used here to save further calculations
                this.fTOC = sum(this.afCarbonAtomsInMolecule .* (arInFlowMassRatios ./ this.oMT.afMolarMass) .* this.oMT.afMolarMass(this.oMT.tiN2I.C));

                % If any of the limits is exceed we close the check valve
                % and the processed water flows back into the waste water
                % tank
                if this.fTOC > 0.2e-6 || this.fPPM > 16
                    this.fPressureDrop = inf;
                    this.bOpen = false;
                else
                    this.fPressureDrop = 0;
                    this.bOpen = true;
                end
            end
            fPressureDrop = this.fPressureDrop;
            % Set the other valve to the corresponding state
            this.oOtherValve.setOpen(~this.bOpen);
        end
    end
end

