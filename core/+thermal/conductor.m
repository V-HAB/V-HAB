classdef (Abstract) conductor < base & event.source
    %CONDUCTOR A thermal connection between two capacity objects
    %   Detailed explanation goes here
    % 
    % ANALOGOUS TO: matter.branch/matter.proc
    % ALTERNATE NAME: transition | transfer | transport | branch
    
    properties (SetAccess = protected)
        
        % Object properties
        
        sName; % The name of the transfer object. Usually a combination of its associated capacity objects' names.
        
        % Internal properties
        
        oLeft;  % The "left" (/upstream) side of the connection.
        oRight; % The "right" (/downstream) side of the connection.
        
    end
    
    properties (Abstract, SetAccess = protected)
        %TODO: evaluate Access = protected.
        
        fConductivity; % Thermal conductivity of connection (unit depends on subclass).
        
    end
    
    methods
        
        function this = conductor(sName, oLeft, oRight)
            % Create a conductive conductor instance and store the name, 
            % associated capacities as well as the (intial) conductivity
            % value.
            
            this.sName = sName;
            
            if ~isa(oLeft, 'thermal.capacity') || ~isa(oRight, 'thermal.capacity')
                this.throw('thermal:conductor', 'Nodes must be of type |thermal.capacity|.');
            end
            
            %TODO: check container!?
            
            this.oLeft  = oLeft;
            this.oRight = oRight;
            
        end
        
        function fOldConductivity = setConductivity(this, fNewConductivity)
            
            %TODO: taint container?
            fOldConductivity = this.fConductivity;
            this.fConductivity = fNewConductivity;
            
        end
        
        function bIsConnected = isConnectedTo(this, oCapacity)
            
            if isequal(oCapacity, this.oLeft) || isequal(oCapacity, this.oRight)
                bIsConnected = true;
            else
                bIsConnected = false;
            end
            
        end
        
        function [sLeftIdentifier, sRightIdentifier] = getCapacityNames(this)
            % Get the names of the associated capacities.
            
            sLeftIdentifier  = this.oLeft.sName;
            sRightIdentifier = this.oRight.sName;
            
        end

    end
    
end

