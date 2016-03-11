classdef LCARSystem < vsys
%LCARSystem System class of the Lithium Chloride Absorber Radiator
%   
%   System is connected to evaporator (SWME) by intermediate venting valve
%   and to environment by an additional venting valve. This valve is
%   foreseen to account for non-condensible gases that accumulate in the
%   absorber. Default: No venting of non-condensible gases.
%
%   Input:
%   none
%
%   Assumptions:
%   none
    
    properties (SetAccess = protected, GetAccess = public)
        % Intermediate Venting Valve (Port to Absorber)
        oIVValveLCAR;
        % Valve for venting non-condensible gases
        oNonCondValve;
        
        fOldTemperature = 293.15;
        fRadiatedPower = 0;
        
        
    end
    
    properties
        % Absorber object needed to adjust temp of environment while
        % simulation is running
        oAbsorber;
        
        toCapacities;
        
        fSinkTemperature = 175;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % A struct containing all necessary parameters for the construction
        % of the LCAR absorber
        tParameters = struct(...
                             'fAbsorberArea',            0.186,  ... [m2]
                             'fGraphitePlateThickness',  0.00143,... [m]
                             'fEmissivity',              0.9,    ... [-]
                             'fAbsorbtivity',            1,      ... [-]
                             'fThermalConductivity',  1600,      ... [W/mK]
                             'fViewFactor',              0.98,   ... [-]
                             'fMassLiCl',                0.426,  ... [kg]
                             'fInitialMassFraction',     0.95,   ... [-]
                             'fInitialTemperature',    293.15,   ... [K]
                             'fInitShroudTemperature', 175       ... [K]
                             );
    end
    
    methods
        function this = LCARSystem(oParent, sName)
            
            % Calling vsys-constructor-method. Third parameter determines
            % how often the .exec() method of this subsystem is called.
            % Possible Interval: 0-inf [s]
            this@vsys(oParent, sName, -1);            
                      
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% LiCL Absorber - two phases contected by a p2p-Proc
            
            % Create the LiCl Absorber
            components.SEAR.stores.LCARAbsorber(this, 'LCARAbsorber', this.tParameters);
            this.oAbsorber = this.toStores.LCARAbsorber;
           
            %% Conecting the components
            
            % Branch 1: Parent system (control valve) into this subsystem
            matter.branch(this, 'LCARAbsorber.In', {}, 'Inlet', 'InletBranch');           
            
            % Branch 2: Out of this subsystem into the parent system (environment)
            matter.branch(this, 'LCARAbsorber.Out', {}, 'Outlet', 'OutletBranch');
            
            %% Creating the thermal system
            
            % Capacities and Heat Sources
            oAbsorberCapacity = thermal.capacity('Absorbent', this.toStores.LCARAbsorber.toPhases.AbsorberPhase);
            oHeatSource = thermal.heatsource('AbsorptionHeat');
            oAbsorberCapacity.setHeatSource(oHeatSource);
            this.addCapacity(oAbsorberCapacity);
            this.toCapacities.Absorber = oAbsorberCapacity;
            
            oRadiatorCapacity = thermal.capacity('Radiator', this.toStores.LCARAbsorber.toPhases.RadiatorSurface);
            oHeatSource = thermal.heatsource('ExternalRadiation');
            oRadiatorCapacity.setHeatSource(oHeatSource);
            this.addCapacity(oRadiatorCapacity);
            this.toCapacities.Radiator = oRadiatorCapacity;
            
            % Conductors
            this.addConductor(thermal.transfers.conductive(oAbsorberCapacity, oRadiatorCapacity, this.tParameters.fThermalConductivity, this.tParameters.fAbsorberArea, 0.1));
            
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Adding solvers to branches
            this.oIVValveLCAR  = solver.matter.manual.branch(this.toBranches.InletBranch);
            this.oNonCondValve = solver.matter.manual.branch(this.toBranches.OutletBranch);
            
            % Here no additional venting at the far end of the absorber
            this.oNonCondValve.setFlowRate(0);
            
        end
        
        function setIfFlows(this, sInlet, sOutlet)
            % This function connects the system and subsystem level branches with each other.
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
            
        end
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            this.fRadiatedPower = this.tParameters.fAbsorberArea * this.tParameters.fEmissivity * this.tParameters.fViewFactor * this.tParameters.fAbsorbtivity * ...
                            this.oMT.Const.fStefanBoltzmann * (((this.fSinkTemperature)^4) - (this.toStores.LCARAbsorber.toPhases.RadiatorSurface.fTemperature^4));
            
            this.toCapacities.Radiator.oHeatSource.setPower(this.fRadiatedPower);
        end
        

        
     end
    
end

