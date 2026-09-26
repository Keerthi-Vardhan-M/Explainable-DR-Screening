function O = blendAttention(I,map)
%BLENDATTENTION RGB visualization of an actual Grad-CAM map.
I = im2single(I); map = min(1,max(0,imresize(single(map),[size(I,1) size(I,2)])));
palette = jet(256); index = min(256,max(1,1+round(double(map)*255)));
heat = reshape(single(palette(index(:),:)),[size(I,1) size(I,2) 3]);
alpha = .55*map; O = I.*(1-alpha)+heat.*alpha;
end
