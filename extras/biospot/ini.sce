// default parameters
exec params.sce;

xset('auto clear', 'on')

// This computes the region containing the nucleii, eliminating most noise
// inside the embryo.
exec embryo_crust.sce;

// -----------------------------------------------------------------------------
// estimate thickness through the DT
//
// Idea (partially implemented)
//
// 1 - compute DT of the inverse ec
// 2 - compute the skeleton
// 3 - median distance along the skeleton is one of your nucleus radius rn along
//     the normal
//   - perhaps have to increase the scale of the skeleton slightly
// 4 - The central line could be obtained as the levelset of the DT at rn, or as
// the skeleton at maximum scale which preserves loops (this is what we did)!!


[skl,dt,vor] = skel(ec);

// Less detail possible - loop preserving
sklt = (skl >= max(skl));

// max(skl) is an indicator of the maximum thickness, or we could read this from
// DT.

figure
imshow(ec+sklt,[]);

figure
imshow(e+2*sklt,[]);

// TODO: signal error if no complete loop was found. Attempt:

if (size(find(sklt),'*') / size(find(ec==1),'*') < 0.01)
  warning('crust may not be a closed loop, yielding failure');
end

// -----------------------------------------------------------------------------
// Filter out very small connected components in the edge map

[L, n] = bwlabel(e);

// Eliminate edge segments smaller than min_length pixels (noise)
for i=1:n
  f = find(L==i);      // linear coordinates of i-th region
  reg_size = size(f,'*');
  if reg_size < min_length
     L(f) = 0;         // merge small regions with the background
  end
end

imshow(L+1, rand(n+1,3));   // note how the small regions are gone

// filtered embryo
ef = im2bw(L,0.5);

// -----------------------------------------------------------------------------
// follow the border and read pixel values to generate a 1D signal

[x,y] = follow(sklt*1);

dims = size(sklt);
s = zeros(x);
ds = s;

for i=1:size(x,'*') do
   s(i) = ef(dims(1) - y(i), x(i)+1);
   ds(i) = dt(dims(1) - y(i), x(i)+1);
end
figure

disp('median nucleii thickness along normal direction:')
rn = sqrt(median(ds))

len=arclength([x y], %t);
plot(len,[s;s(1)]);

// -----------------------------------------------------------------------------
// Use a RANSAC fitting to align and possibly determine a finer spacing
// corresponding to the maximum possible number of inliers

// from rn above we know a range of tangential radii rt that must be the truth, 
// between 0.5*rn and 1.5*rn for sure

// let's first give an estimate through the median spacing between edges along
// the medial line

zc = find(s<>0);

zc_len = len(zc);

n_zc = length(zc);

widths = zc_len(2:n_zc) - zc_len(1:(n_zc-1));


disp('median nucleii thickness along tangential direction:')
median_rt = median(widths)/2;

disp('The initial nucleus model has diameters:' + string(median_rt*2) + ' by ' + string(rn*2) + ' pixels');


// -----------------------------------------------------------------------------
// Plot the lengths along the normals to the central curve