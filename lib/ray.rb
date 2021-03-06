OBJS = [
  # オブジェクト種類     中心座標          パラメータ      反射率  色(1白 0黒)
  [:BALL,         -6.0,     2.0,   20.0,   7.0, 0, 0,       0,      1],
  [:BALL,          -2.0,   -2.0,   6.0,   2.0, 0, 0,      0.5,   1],
  [:BALL,          1.0,    -1.0,   15.0,    2.0, 0, 0,    0.5,    1],
  # PLANE(平面)は平面上の1点と法線ベクトルを指定する
  [:PLANE,         0.0, -35.0, 0.0,   0.0, 1.0, 0,   0,    1],
]

LIGHTS = [
  # 光源種類       座標              パラメータ    光源強さ
  [:POINT,         10.0, 30.0, 0.0,     0, 0, 0, 0,   1]
]

OBJ_KIND = 0
OBJ_CENTER_X = 1
OBJ_CENTER_Y = 2
OBJ_CENTER_Z = 3

OBJ_BALL_SIZE = 4

OBJ_PLANE_HX = 4
OBJ_PLANE_HY = 5
OBJ_PLANE_HZ = 6

OBJ_REFRECT_RATIO = 7
OBJ_COLOR = 8

MAX_REF_NUM = 10


def make_bmp(image)
  fheader = ['BM', 65536 + 12 + 14, 0, 0, 12 + 14 + 256].pack("a2VvvV")
  iheader = [12, 256, 256, 1, 8].pack("Vvvvv")
  File.open("ray.bmp", "w") do |fp|
    fp.print fheader

    fp.print iheader
    0.upto(256) do |n|
      fp.print [n, n, n].pack('c3')
    end
    65535.downto(0) do |i|
      fp.printf "%c", image[i]
    end
  end
end

def get_color(sx, sy, sz, ox, oy, oz, objlst, refnum)
  t, cox, coy, coz, cobj = intersect(sx, sy, sz, ox, oy, oz, objlst)
  # 視点から衝突箇所までのベクトルを得る
  if t == 0 then
    return 1.0
  end
  covx = cox - ox
  covy = coy - oy
  covz = coz - oz
  vs = Math.sqrt(covx * covx + covy * covy + covz * covz)
  if vs == 0 then
    return 1.0
  end
  covx = covx / vs
  covy = covy / vs
  covz = covz / vs
  hvx =0
  hvy = 0
  hvz = 0
  bcol = 0

  case cobj[OBJ_KIND]
  when :BALL
    # 球の法線ベクトルを得る
    hvx = cox - cobj[OBJ_CENTER_X]
    hvy = coy - cobj[OBJ_CENTER_Y]
    hvz = coz - cobj[OBJ_CENTER_Z]
    hvs = Math.sqrt(hvx * hvx + hvy * hvy + hvz * hvz)
    hvx = hvx / hvs
    hvy = hvy / hvs
    hvz = hvz / hvs


    # 内積を取って色を計算する.散乱光による色がbcolに入る
    bcol = hvx * covx + hvy * covy + hvz * covz
    bcol = -bcol
  #  bcol = bcol.abs
    if bcol < 0 then
      return 1.0
    end
    
  when :PLANE
    # 平面の法線ベクトルを得る
    hvx = cobj[OBJ_PLANE_HX]
    hvy = cobj[OBJ_PLANE_HY]
    hvz = cobj[OBJ_PLANE_HZ]
    hvs = Math.sqrt(hvx * hvx + hvy * hvy + hvz * hvz)
    hvx = hvx / hvs
    hvy = hvy / hvs
    hvz = hvz / hvs
    
    # 内積を取って色を計算する.散乱光による色がbcolに入る
    bcol = hvx * covx + hvy * covy + hvz * covz
    bcol = bcol.abs
    if bcol < 0 then
      return 1.0
    end
  else
    return 1.0
  end

  # 光源
  ip = covx * hvx + covy * hvy + covz * hvz
  ip = -ip
  rvx = 2 * ip * hvx - covx
  rvy = 2 * ip * hvy - covy
  rvz = 2 * ip * hvz - covz
#=begin
   bcol = bcol * 0.5
   LIGHTS.each do |lit|
     lposx = lit[OBJ_CENTER_X]
     lposy = lit[OBJ_CENTER_Y]
     lposz = lit[OBJ_CENTER_Z]
     lvx = cox - lposx
     lvy = coy - lposy
     lvz = coz - lposz
     lvs = Math.sqrt(lvx * lvx + lvy * lvy + lvz * lvz)

     t, dmyx, dmyy, dmyz, dmyo = intersect(lvx, lvy, lvz, lposx, lposy, lposz, objlst)
     if t and  (t - 1).abs < 0.001 then
       c = (lvx * sx + lvz * sy + lvz * sz) / lvs * 0.5
#       c = -c.abs
       if c > 0 then
         bcol += c
       end
     else
     end
  end
#=end
  # 反射
  if refnum < MAX_REF_NUM then
    return (bcol * (1.0 - cobj[OBJ_REFRECT_RATIO])) + (get_color(rvx, rvy, rvz, cox, coy, coz, objlst, refnum + 1) * cobj[OBJ_REFRECT_RATIO])
  else
    return bcol * (1.0 - cobj[OBJ_REFRECT_RATIO])
  end
end

def intersect(sx, sy, sz, ox, oy, oz, objlst)
  # 与えられた座標データから正規化された視線ベクトルを得る
  vx = sx
  vy = sy
  vz = sz
  vs = Math.sqrt(vx * vx + vy * vy + vz * vz)
  vx = vx / vs
  vy = vy / vs
  vz = vz / vs

  mint = nil
  cobj = nil


  objlst.each do |obj|
    cx = obj[OBJ_CENTER_X] - ox
    cy = obj[OBJ_CENTER_Y] - oy
    cz = obj[OBJ_CENTER_Z] - oz
  
    case obj[OBJ_KIND]
    when :BALL
      # 球の場合の衝突判定
      siz = obj[OBJ_BALL_SIZE]
      b = (vx * cx + vy * cy + vz * cz)
      c = cx * cx + cy * cy + cz * cz  - siz * siz
#      print "#{a} #{b} #{c} \n"
      h = b * b - c
      if h < 0 then
        next
      end
      h1 = Math.sqrt(h)
      if b - h1 > 0.001 then
        t = b - h1
      else
        t = b + h1
      end

      if t.abs <= 0.001 then
        next
      end

      if !mint or t < mint then
        mint = t
        cobj = obj
      end
      
    when :PLANE
      # 平面の場合の衝突判定
      hvx = obj[OBJ_PLANE_HX]
      hvy = obj[OBJ_PLANE_HY]
      hvz = obj[OBJ_PLANE_HZ]

      ta = (hvx * cx + hvy * cy + hvz * cz)
      tb = (hvx * vx + hvy * vy + hvz * vz)
      #ta = -ta

      if tb == 0 or (t = ta / tb) < 0.0001 then
        next
      end

      if !mint or t < mint then
        mint = t
        cobj = obj
      end
    end
  end

  if mint then
    [mint / vs, mint * vx + ox, mint * vy + oy , mint * vz + oz, cobj]
  else
    [nil, 0, 0, 0, [nil]]
  end
end
    
image = []
0.upto(256) do |x|
  0.upto(256) do |y|
    rx = ((128.0 - x) / 256.0)
    ry = ((128.0 - y) / 256.0)
    rz = 1 - Math.sqrt(rx * rx + ry * ry)
    c = get_color(rx, ry, rz, 0, 0, 0, OBJS, 0)
    image[x + y * 256] = c * 255
  end
end
make_bmp(image)
