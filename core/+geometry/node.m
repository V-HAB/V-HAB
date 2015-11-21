classdef node < base & event.source
    %NODE Basic geometry node
    % Needs to be set as parent class by all geometric shape classes.
    %
    % Good starting point for geometry:
    % http://www.web3d.org/realtime-3d/specification/version/V3.3
    % more specific:
    % http://www.web3d.org/files/specifications/19775-1/V3.3/index.html
    % -> X3D/WebGL developed and supported by major browsers.
    %
    % Functionality could be implemented to work with X3D, i.e. the package
    % path should be something like x3d.geometry.node or could just provide
    % basic information which is used somewhere else to construct valid X3D
    % models/files (so basically a view of this node/obj).
    
    properties
    end
    
    methods
    end
    
end

