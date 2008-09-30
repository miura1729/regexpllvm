OBJS = [
  # オブジェクト種類     中心座標          パラメータ      反射率  色(1白 0黒)
#  [:BALL,          1.0,     2.0,   10.0,   4.0, 0, 0,       0,      1],
#  [:BALL,          -4.0,   -8.0,   15.0,   5.0, 0, 0,       0.5,   1],
 [:BALL,          4.0,    -1.0,   50.0,   15.0, 0, 0,       0,    1],
  # PLANE(平面)は平面上の1点と法線ベクトルを指定する
  [:PLANE,         0.0, -50.0, 0.0,   0.0, -1.0, 0,   1,    1],
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
OBJ_REFRECT_COLOR = 8

MAX_REF_NUM = 2


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
  cox, coy, coz, cobj = collision(sx, sy, sz, ox, oy, oz, objlst)
  # 視点から衝突箇所までのベクトルを得る
  covx = cox - ox
  covy = coy - oy
  covz = coz - oz
  vs = Math.sqrt(covx * covx + covy * covy + covz * covz)
  if vs == 0 then
    return 0
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
    if bcol < 0 then
      return 0.0
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
    if bcol < 0 then
      return 0.0
    end

  else
    return 0.0
  end

  # 反射
  if refnum < MAX_REF_NUM then
    ip = covx * hvx + covy * hvy + covz * hvz
    rvx = 2 * ip * hvx - covx
    rvy = 2 * ip * hvy - covy
    rvz = 2 * ip * hvz - covz
    return bcol * (1.0 - cobj[OBJ_REFRECT_RATIO]) + get_color(rvx, rvy, rvz, cox, coy, coz, objlst, refnum + 1) * cobj[OBJ_REFRECT_RATIO]
  else
    return bcol * (1.0 - cobj[OBJ_REFRECT_RATIO])
  end
end

def collision(sx, sy, sz, ox, oy, oz, objlst)
  # 与えられた座標データから正規化された視線ベクトルを得る
  vx = sx - ox
  vy = sy - oy
  vz = sz - oz
  vs = Math.sqrt(vx * vx + vy * vy + vz * vz)
  vx = vx / vs
  vy = vy / vs
  vz = vz / vs

  mint = nil
  cobj = nil


  objlst.each do |obj|
    cx = obj[OBJ_CENTER_X] - ox
    cy = obj[OBJ_CENTER_Y] - ox
    cz = obj[OBJ_CENTER_Z] - ox
  
    case obj[OBJ_KIND]
    when :BALL
      # 球の場合の衝突判定
      siz = obj[OBJ_BALL_SIZE]
      a = vx * vx + vy * vy + vz * vz
      b = (vx * cx + vy * cy + vz * cz)
      c = cx * cx + cy * cy + cz * cz  - siz * siz
#      print "#{a} #{b} #{c} \n"
      h = b * b - a * c
      if h < 0 then
        next
      end
      t = (b + Math.sqrt(h)) / a
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

      if tb == 0 or (t = ta / tb) < 0 then
        next
      end
      if !mint or t < mint then
        mint = t
        cobj = obj
      end
    end
  end

  if mint then
    [mint * vx + ox, mint * vy + oy , mint * vz + oz, cobj]
  else
    [0, 0, 0, [nil]]
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
