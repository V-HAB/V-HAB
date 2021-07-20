classdef solid < matter.procs.exmes.solid
    %SOLID An EXME that interfaces with a solid phase
    %   The main purpose of this class is to provide the method
    %   getPortProperties() which returns the pressure and temperature of
    %   the attached phase. 
    
    methods
        function this = solid(oPhase, sName)
            %% solid exme class constructor
            % only calls the parent class constructor, nothing special
            %
            % Required Inputs:
            % oPhase:   the phase the exme is attached to
            % sName:    the name of the processor
            this@matter.procs.exmes.solid(oPhase, sName);
        end
        function [ fFlowRate, arPartials, afProperties, arCompoundMass ] = getFlowData(this, fFlowRate)
            %% ExMe getFlowData
            % This function can be called to receive information about the
            % exme flow properties. 
            %
            % Outputs:
            % fFlowRate:    current mass flow rate in kg/s with respect to
            %               the connected phase (negative values mean the
            %               mass of this.oPhase is beeing reduced)
            % arPartials:   A vector with the length (1,oMT.iSubstances)
            %               with the partial mass ratio of each substance in the current
            %               fFlowRate. The sum of this vector is 1 and
            %               multipliying arPartials with fFlowRate yields
            %               the partial mass flow rates for each substance
            % afProperties: A vector with two entries, the flow temperature
            %               and the flow specific heat capacity
            % trCompoundMass: A strcut containing each compound mass as
            %                 field and within each field the composition
            %                 of this compound mass
            
            % The flow rate property of the flow is unsigned, so we have to
            % add it again by multiplying with the iSign property of this
            % exme. 
            if nargin >= 2 && ~isempty(fFlowRate)
                fFlowRate  =  fFlowRate * this.iSign;
            else
                fFlowRate  =  this.oFlow.fFlowRate * this.iSign;
            end
            % This exme is connected to a P2P processor, so we can get
            % the properties from the connected flow.
            arPartials   = this.oFlow.arPartialMass;
            afProperties = [ this.oFlow.fTemperature this.oFlow.fSpecificHeatCapacity ];
            arCompoundMass = this.oFlow.arCompoundMass;
        end
    end
end

