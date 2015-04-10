classdef main < vsys
    %SIMPLE_AVGD_CREW Dummy system representing a crew, still incomplete.
    %   Right now, only O2 inhaled and converted to CO2, 80% of that
    %   exhaled.
    %
    %%TODO
    % - should inherit from vman.main!
    
    properties (SetAccess = protected, GetAccess = public)
        % Lung volume in m^3
        fLungVolume = 0.005;
        
        % Absorption rate of O2 in kg/s - assuming 0.9kg/d!
        fOxygenRequired = 0.9 / 3600 / 24;
        
        % Ventilation rate in kg/s, converted from 10L/min
        % 1m3 at 1bar -> ~1.2kg air; 10L = 0.01m3 -> 0.01 * 1.2 -> to sec
        fVentilation = 12 * 0.001 * 1.2 / 60;
        
        
        % Initial C content of 'inner' lung phase in kg. Set to a kilogram
        % value that is sufficient for a longer sim, so used an approx.
        % value of 18% of C in humans for a 80kg crewmember.
        % See http://www.rodiehr.de/d_03_grundstoffe_im_koerper.htm
        fInitialCarbon = 0.18 * 80;
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        % Manual solver to pump air in!
        oLungFlowrate;
    end
    
    methods
        function this = main(oParent, sName, fCrewSize)
            this@vsys(oParent, sName, 60);
            
            % Import - NEVER more than once per scope!!1!
            import vman.full_models.to_go.simple_avgd_crew.*;
            
            
            %% Create matter flow 'infrastructure'
            
            % Create store representing the Lung, add 0.001m3 to the lung
            % volume that will be occupied by a solid phase that does the
            % conversion of O2 and C to CO2
            %CHECK-S solid phases probably not yet sufficiently implemented
            %        so for now, two gas phases and therefore just LungVol
            this.addStore(matter.store(this.oData.oMT, 'Lung', this.fLungVolume));% + 0.001));
            
            this.toStores.Lung.createPhase('air', this.fLungVolume);
            
            % 'Inner' Solid phase with some C, 0.001m^3 volume.
            %CHECK-S solid phases probably not yet sufficiently implemented
            %matter.phases.solid(this.toStores.Lung, 'inner', struct(), 0.001, 293.15);
            matter.phases.gas(this.toStores.Lung, 'inner', struct('C', this.fInitialCarbon), this.fLungVolume, 293.15);
            
            
            % 'Outer' EXMEs to connect the crew to the atmosphere
            matter.procs.exmes.gas(this.toStores.Lung.aoPhases(1), 'intake');
            matter.procs.exmes.gas(this.toStores.Lung.aoPhases(1), 'outlet');
            
            % EXMEs to transfer matter between lung and inner part
            matter.procs.exmes.gas(this.toStores.Lung.aoPhases(1), 'o2_out');
            matter.procs.exmes.gas(this.toStores.Lung.aoPhases(1), 'co2_in');
            
            matter.procs.exmes.gas(this.toStores.Lung.aoPhases(2), 'o2_in');
            matter.procs.exmes.gas(this.toStores.Lung.aoPhases(2), 'co2_out');
            
            
            %% Processors
            lib.p2ps.oxygen_intake(this.toStores.Lung, 'intake_o2',  'air.o2_out',    'inner.o2_in');
            lib.p2ps.co2_outlet   (this.toStores.Lung, 'output_co2', 'inner.co2_out', 'air.co2_in');
            
            lib.manips_partial.o2_to_co2('o2_co2_conv', this.toStores.Lung.aoPhases(2));
            
            
            %% Branches
            this.createBranch('Lung.intake', {}, 'Intake');
            this.createBranch('Lung.outlet', {}, 'Outlet');
            
            
            %% Add solvers, initialize flow rates and finish
            this.oLungFlowrate = solver.matter.manual.branch(this.aoBranches(1));
            
            % Max. flow rate 100L (SLM, 0.02) for 0.1bar diff ... whyever.
            oSolverEq = solver.matter.equalizer.branch(this.aoBranches(2), this.fVentilation * 2.5, 10000);
            oSolverEq.iDampFR = 5;
            %oBranchOut = solver.matter.manual.branch(this.aoBranches(2));
            %oBranchOut.setFlowRate(this.fVentilation - this.fOxygenRequired);
            
            % Set the requested oxygen for the p2p ...
            this.toStores.Lung.toProcsP2P.intake_o2.setRequestedOxygen(this.fOxygenRequired);
            
            % ... and the manual solver flow rate to the ventilation rate
            this.oLungFlowrate.setFlowRate(-1 * this.fVentilation);
            %TODO check - could also use reqO2 -> times 4, 5? -> times five
            %     with 20% oxygen in air, if human would extract ALL
            %     oxygen, we would need five times the o2 requirement as a
            %     flow rate. As the human extracts much less, maybe need
            %     another factor of four, five (21% down to 17%?)
            
            this.seal();
        end
        
        
        function connectIfs(this, sIntake, sOutlet)
            this.connectIF('Intake',  sIntake);
            this.connectIF('Outlet', sOutlet);
        end
        
        
        
        function setLoadLevel(this, rLoad)
            %TODO
            % - convert load (0-1) to some o2 absorption rate
            % - set for o2 in p2p
            % - adjust manual solver IN flowrate -> o2 partial FR must be
            %   probably four times the absorption rate (normally exhaled
            %   air has probably 16% oxygen = 5% less -> ~1/4th used (??)
        end
    end
    
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            %TODO
            % - check O2 levels in inflowing air, check if in FR needs to
            %   be increased (lower oxygen)? Or just warn in o2 p2p if O2
            %   inflow rate is not at least four times the requested oxygen
            %   intake rate?
        end
        
     end
end

